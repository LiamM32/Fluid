module fluid.text;

import std.algorithm;

import fluid.node;
import fluid.style;
import fluid.backend;
import fluid.typeface;


@safe:


/// Draws text: handles updates, formatting and styling.
struct Text(T : Node) {

    public {

        /// Node owning this text struct.
        T node;

        /// Texture generated by the struct.
        /// Note: Lifetime of the texture is managed by the struct. The texture will be destroyed every time the text
        /// changes.
        Texture texture;

        /// Underlying text.
        string value;

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

    this(T node, string text) {

        this.node = node;
        opAssign(text);

    }

    /// Copy the text, clear ownership and texture.
    this(ref const Text text) {

        this.node = null;
        this.texture = texture.init;
        this.value = text.value;

    }

    ~this() @trusted {

        texture.destroy();

    }

    inout(FluidBackend) backend() inout

        => node.tree.backend;

    string opAssign(string text) {

        // Ignore if there's no change to be made
        if (text == value) return text;

        // Request update otherwise
        node.updateSize;
        return value = text;

    }

    string opOpAssign(string operator)(string text) {

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

    alias minSize = size;

    /// Set new bounding box for the text and redraw it.
    void resize() {

        auto style = node.pickStyle;
        auto dpi = backend.dpi;

        style.setDPI(dpi);

        auto newSize = style.getTypeface.measure(value);

        // Size changed, queue regeneration
        if (_wrap || newSize != _sizeDots) {
            _sizeDots = newSize;
            _pendingGeneration = true;
            _wrap = false;
        }

    }

    /// Set new bounding box for the text; wrap the text if it doesn't fit in boundaries. Redraw it.
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
        if (_wrap != wrap || newSize != _sizeDots) {
            _sizeDots = newSize;
            _pendingGeneration = true;
            _wrap = wrap;
        }

    }

    /// Generate or regenerate the texture.
    void generate() @trusted {

        const style = node.pickStyle;
        const dpi = node.backend.dpi;

        // Destroy old texture if needed
        if (texture !is texture.init) {

            backend.unloadTexture(texture);
            texture = texture.init;

        }

        _pendingGeneration = false;

        // Empty, nothing to do
        if (_sizeDots.x < 1 || _sizeDots.y < 1) return;

        auto image = generateColorImage(
            cast(int) _sizeDots.x,
            cast(int) _sizeDots.y,
            color!"0000"
        );

        // TODO actually use the splitter for rendering??
        style.getTypeface.draw(image, Rectangle(0, 0, _sizeDots.tupleof), value, color!"fff", _wrap);

        // Load texture
        texture = backend.loadTexture(image);
        texture.dpiX = cast(int) dpi.x;
        texture.dpiY = cast(int) dpi.y;

    }

    /// Draw the text.
    void draw(const Style style, Vector2 position) @trusted {

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
        if (texture !is texture.init) {

            backend.drawTextureAlign(texture, rectangle, style.textColor, value);

        }

    }

    void draw(const Style style, Rectangle rectangle) {

        draw(style, Vector2(rectangle.x, rectangle.y));

    }

    string toString() const {

        return value;

    }

}
