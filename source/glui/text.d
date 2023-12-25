module glui.text;

import std.algorithm;

import glui.node;
import glui.style;
import glui.backend;
import glui.typeface;


@safe:


/// Draws text: handles updates, formatting and styling.
struct Text(T : GluiNode) {

    /// Node owning this text struct.
    T node;

    /// Texture generated by the struct.
    /// Note: Lifetime of the texture is managed by the struct. The texture will be destroyed every time the text
    /// changes.
    Texture texture;

    /// Underlying text.
    string value;

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

    inout(GluiBackend) backend() inout

        => node.tree.backend;

    string opAssign(string text) {

        // Ignore if there's no change to be made
        if (text == value) return text;

        // Request update otherwise
        node.updateSize;
        return value = text;

    }

    /// Get the size of the text.
    Vector2 size() const {

        return Vector2(texture.width, texture.height);

    }

    alias minSize = size;

    /// Set new bounding box for the text and redraw it.
    void resize() {

        auto style = node.pickStyle;

        style.setDPI(backend.hidpiScale);

        const size = style.typeface.measure(value);

        resizeImpl(style, size, false);

    }

    /// Set new bounding box for the text; wrap the text if it doesn't fit in boundaries. Redraw it.
    void resize(alias splitter = Typeface.defaultWordChunks)(Vector2 space, bool wrap = true) {

        auto style = node.pickStyle;

        style.setDPI(backend.hidpiScale);

        const size = style.typeface.measure!splitter(space, value, wrap);

        resizeImpl(style, size, wrap);

    }

    private void resizeImpl(const Style style, Vector2 size, bool wrap) @trusted {

        // Empty, nothing to do
        if (size.x < 1 || size.y < 1) return;

        auto image = generateColorImage(
            cast(int) size.x,
            cast(int) size.y,
            color!"0000"
        );

        style.drawText(image, Rectangle(0, 0, size.tupleof), value, color!"fff", wrap);

        auto oldtexture = texture.id;

        // Destroy old texture if needed
        if (texture !is texture.init) {

            backend.unloadTexture(texture);

        }

        // Load texture
        texture = backend.loadTexture(image);

    }

    /// Draw the text.
    void draw(const Style style, Vector2 position) @trusted {

        import std.math;

        if (texture !is texture.init) {

            // Round down to keep correct hinting
            position.x = floor(position.x);
            position.y = floor(position.y);

            backend.drawTexture(texture, position, style.textColor);

        }

    }

    void draw(const Style style, Rectangle rectangle) {

        draw(style, Vector2(rectangle.x, rectangle.y));

    }

    string toString() const {

        return value;

    }

}
