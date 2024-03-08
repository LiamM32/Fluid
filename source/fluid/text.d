module fluid.text;

import std.range;
import std.algorithm;

import fluid.node;
import fluid.style;
import fluid.backend;
import fluid.typeface;


@safe:


/// Create a Text struct with given range as a text layer map.
Text!(T, LayerRange) mapText(T : Node, LayerRange)(T node, const char[] text, LayerRange range, size_t layerCount) {

    return typeof(return)(node, text, range, layerCount);

}

/// Draws text: handles updates, formatting and styling.
struct Text(T : Node, LayerRange = TextRange[]) {

    static assert(isForwardRange!(LayerRange, TextRange), "LayerRange must be a valid forward TextRange range");

    public {

        /// Node owning this text struct.
        T node;

        /// Textures generated by the struct.
        TextureGC[] textures;

        /// Underlying text.
        const(char)[] value;

        /// Range determining layers in the text.
        ///
        /// Ranges should not overlap, and must be ordered by `start`. If a piece of text is not matched, it is assumed
        /// to belong to layer 1.
        LayerRange layerMap;

    }

    private {

        /// Text bounding box size, in dots.
        Vector2 _sizeDots;

        /// If true, text will be wrapped if it doesn't fit available space.
        bool _wrap;

        /// If true, the text is awaiting to be regenerated.
        bool _pendingGeneration;

    }

    alias minSize = size;
    alias value this;

    this(T node, const(char)[] text, LayerRange layerMap = LayerRange.init, size_t layerCount = 1) {

        this.node = node;
        this.textures = new TextureGC[layerCount];
        this.layerMap = layerMap;
        opAssign(text);

    }

    /// Copy the text, clear ownership and texture.
    this(Text text) const {

        this.node = null;
        this.textures = new TextureGC[text.textures.length];
        this.value = text.value;
        this.layerMap = text.layerMap.save;

    }

    inout(FluidBackend) backend() inout

        => node.tree.backend;


    const(char)[] opAssign(const(char)[] text) {

        // Ignore if there's no change to be made
        if (text == value) return text;

        // Request update otherwise
        node.updateSize;
        return value = text;

    }

    const(char)[] opOpAssign(string operator)(const(char)[] text) {

        node.updateSize;
        return mixin("value ", operator, "= text");

    }

    /// Get the size of the text.
    Vector2 size() const {

        const scale = backend.hidpiScale;

        return Vector2(
            _sizeDots.x / scale.x,
            _sizeDots.y / scale.y,
        );

    }

    /// Set or get the number of layers generated. Extra layers make it possible to apply different styles to different
    /// parts of the text, but slow down the process.
    ///
    /// Note: Due to present limitations in the implementation, it is not currently possible to mix different typefaces
    /// within the same Text.
    size_t layerCount() const {

        return textures.length;

    }

    /// ditto
    size_t layerCount(size_t i) {

        return textures.length = i;

    }

    alias minSize = size;

    /// Set new bounding box for the text.
    void resize() {

        auto style = node.pickStyle;
        auto dpi = backend.dpi;

        style.setDPI(dpi);

        auto newSize = style.getTypeface.measure(value);

        // Size changed, queue regeneration
        _sizeDots = newSize;
        _pendingGeneration = true;
        _wrap = false;

    }

    /// Set new bounding box for the text; wrap the text if it doesn't fit in boundaries.
    void resize(alias splitter = Typeface.defaultWordChunks)(Vector2 space, bool wrap = true) {

        auto style = node.pickStyle;
        auto dpi = backend.dpi;
        auto scale = backend.hidpiScale;

        // Apply DPI
        style.setDPI(dpi);
        space.x *= scale.x;
        space.y *= scale.y;

        auto newSize = style.getTypeface.measure!splitter(space, value, wrap);

        // Size changed, queue regeneration
        _sizeDots = newSize;
        _pendingGeneration = true;
        _wrap = wrap;

        // TODO Don't redraw if nothing changed. Consider all of _sizeDots, _wrap and value.

    }

    /// Generate or regenerate the textures.
    void generate() @trusted {

        _pendingGeneration = false;

        // Remove old textures
        textures[] = TextureGC.init;

        // Empty, nothing to do
        if (_sizeDots.x < 1 || _sizeDots.y < 1) return;

        // No textures to generate, nothing to do
        if (textures.length == 0) return;

        const style = node.pickStyle;
        const typeface = style.getTypeface;
        const dpi = node.backend.dpi;

        // Prepare images to use as target
        auto images = iota(textures.length)
            .map!(a => generateColorImage(
                cast(int) _sizeDots.x,
                cast(int) _sizeDots.y,
                color("#0000")
            ))
            .array;

        auto ruler = TextRuler(typeface, _sizeDots.x);

        // Copy the layer range, make it infinite
        auto layerMap = this.layerMap.save.chain(TextRange.init.repeat);

        // Run through the text
        foreach (index, line; Typeface.lineSplitterIndex(value)) {

            ruler.startLine();

            // Split on words
            // TODO use the splitter provided when resizing
            foreach (word, penPosition; Typeface.eachWord(ruler, line, _wrap)) {

                const wordEnd = index + word.length;

                // Split the word based on the layer map
                while (index != wordEnd) {

                    const remaining = wordEnd - index;
                    auto wordFragment = word[$ - remaining .. $];
                    auto range = layerMap.front;

                    // Advance the layer map if exceeded the start
                    if (range.start < index) {
                        layerMap.popFront;
                        continue;
                    }

                    size_t layer = 0;

                    // Match found here
                    if (range.start <= index) {

                        // Find the end of the range
                        const end = min(wordEnd, range.end) - index;
                        wordFragment = wordFragment[0 .. end];
                        layer = range.layer;

                    }

                    // Match found later
                    else if (range.start < wordEnd) {

                        wordFragment = wordFragment[0 .. range.start - index];

                    }

                    // Redirect unknown layers to first layer
                    if (layer > textures.length) layer = 0;

                    // Draw the fragment
                    typeface.drawLine(images[layer], penPosition, wordFragment, color("#fff"));

                    // Update the index
                    index += wordFragment.length;

                }

            }

        }

        // Load textures
        foreach (i, ref texture; textures) {

            // Load texture
            texture = TextureGC(backend, images[i]);
            texture.dpiX = cast(int) dpi.x;
            texture.dpiY = cast(int) dpi.y;

            images[i].destroy();

        }

    }

    /// Draw the text.
    void draw(const Style style, Vector2 position) {

        scope const Style[1] styles = [style];

        draw(styles, position);

    }

    /// ditto
    void draw(scope const Style[] styles, Vector2 position)
    in (styles.length, "No styles were passed to draw(Style[], Vector2)")
    do {

        import std.math;
        import fluid.utils;

        const rectangle = Rectangle(position.tupleof, size.tupleof);
        const screen = Rectangle(0, 0, node.io.windowSize.tupleof);

        // Ignore if offscreen
        if (!overlap(rectangle, screen)) return;

        // Regenerate the texture if needed
        if (_pendingGeneration) {

            generate();

        }

        // Draw the texture if present
        foreach (i, ref texture; textures) {

            if (texture is texture.init) continue;

            debug assert(texture.tombstone);
            debug assert(!texture.tombstone.isDestroyed);

            auto style = i < styles.length
                ? styles[i]
                : styles[0];

            backend.drawTextureAlign(texture, rectangle, style.textColor, value);

        }

    }

    /// ditto
    deprecated("Use draw(Style, Vector2) instead. Hint: Use fluid.utils.start(Rectangle) to get the position vector.")
    void draw(const Style style, Rectangle rectangle) {

        // Should this "crop" the result?

        draw(style, Vector2(rectangle.x, rectangle.y));

    }

    string toString() const {

        return value.idup;

    }

}

struct TextRange {

    /// Start and end of this range. Start is inclusive, end is exclusive. The range may exceed text boundaries.
    auto start = size_t.max;

    /// ditto
    auto end = size_t.max;

    invariant(start <= end);

    /// Layer the text matched by this range is assigned to. The layer should be a valid index into `Text.textures`.
    size_t layer;

    ptrdiff_t opCmp(const TextRange that) const {

        return cast(ptrdiff_t) this.start - cast(ptrdiff_t) that.start;

    }

}

unittest {

    import fluid.space;

    auto io = new HeadlessBackend;
    auto root = vspace();
    auto text = Text!Space(root, "Hello, green world!");

    // Set colors for each part
    Style[4] styles;
    styles[0].textColor = color("#000000");
    styles[1].textColor = color("#1eff00");
    styles[2].textColor = color("#55b9ff");
    styles[3].textColor = color("#0058f1");

    // Define regions
    text.layerCount = styles.length;
    text.layerMap = [
        TextRange(7, 12, 1),   // green
        TextRange(13, 14, 2),  // w
        TextRange(14, 15, 3),  // o
        TextRange(15, 16, 2),  // r
        TextRange(16, 17, 3),  // l
        TextRange(17, 18, 2),  // d
    ];

    // Prepare the tree
    root.io = io;
    root.draw();

    // Draw the text
    io.nextFrame;
    text.resize();
    text.draw(styles, Vector2(0, 0));

    // Make sure each texture was drawn with the rigth color
    foreach (i; 0..4) {

        io.assertTexture(text.textures[i].texture, Vector2(), styles[i].textColor);

    }

    // TODO Is there a way to reliably test if the result was drawn properly? Sampling specific pixels maybe?

}

unittest {

    import fluid.space;

    auto io = new HeadlessBackend;
    auto root = vspace();

    Style[2] styles;
    styles[0].textColor = color("#000000");
    styles[1].textColor = color("#1eff00");

    auto layers = recurrence!"a[n-1] + 1"(0)
        .map!(a => TextRange(a, a+1, a % 2));

    auto text = mapText(root, "Hello, World!", layers, styles.length);

    // Prepare the tree
    root.io = io;
    root.draw();

    // Draw the text
    io.nextFrame;
    text.resize(Vector2(50, 50));
    text.draw(styles, Vector2(0, 0));

}
