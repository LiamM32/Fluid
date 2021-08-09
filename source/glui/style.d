///
module glui.style;

import raylib;

import std.range;
import std.string;
import std.typecons;
import std.algorithm;

import glui.utils;

/// Node theme.
alias Theme = Style[immutable(StyleKey)*];

/// An empty struct used to create unique style type identifiers.
struct StyleKey { }

/// Create a new style initialized with given D code.
///
/// raylib and std.string are accessible inside by default.
Style style(string init)() {

    auto result = new Style;
    result.update!init;

    return result;

}

/// Contains a style for a node.
class Style {

    // Text options
    struct {

        /// Font to be used for the text.
        Font font;

        /// Font size (height) in pixels.
        float fontSize = 24;

        /// Line height, as a fraction of `fontSize`.
        float lineHeight = 1.4;

        /// Space between characters, relative to font size.
        float charSpacing = 0.1;

        /// Space between words, relative to the font size.
        float wordSpacing = 0.5;

        /// Text color.
        Color textColor = Colors.BLACK;

        /// If true, text will be wrapped. Requires align=fill on height.
        deprecated("textWrap is now always enabled and this property has no effect.")
        bool textWrap = true;
        // TODO for other aligns

    }

    // Background
    struct {

        /// Background color of the node.
        Color backgroundColor;

    }

    // Misc
    struct {

        /// Cursor icon to use while this node is hovered.
        ///
        /// Custom image cursors are not supported yet.
        MouseCursor mouseCursor;

    }

    this() {

        font = GetFontDefault;

    }

    /// Get the default, empty style.
    static Style init() {

        static Style val;
        if (val is null) val = new Style;
        return val;

    }

    ///
    private void update(string code)() {

        mixin(code);

    }

    /// Measure space given text will use.
    ///
    /// Note: Enables wrapping by default, unless given space is empty.
    ///
    /// Params:
    ///     availableSpace = Space available for drawing.
    ///     text           = Text to draw.
    /// Returns:
    ///     If `availableSpace` is a vector, returns the result as a vector.
    ///
    ///     If `availableSpace` is a rectangle, returns a rectangle of the size of the result, offset to the position
    ///     of the given rectangle.
    Vector2 measureText(Vector2 availableSpace, string text) const {

        auto wrapped = wrapText(availableSpace.x, text, availableSpace.x == 0);

        return Vector2(
            wrapped.map!"a.width".maxElement,
            wrapped.length * fontSize * lineHeight,
        );

    }

    /// Ditto
    Rectangle measureText(Rectangle availableSpace, string text) const {

        const vec = measureText(
            Vector2(availableSpace.width, availableSpace.height),
            text,
        );

        return Rectangle(
            availableSpace.x, availableSpace.y,
            vec.x, vec.y
        );

    }

    /// Draw text using the params
    void drawText(Rectangle rect, string text) const {

        // Text position from top, relative to given rect
        double top = 0;

        const totalLineHeight = fontSize * lineHeight;

        // Draw each line
        foreach (line; wrapText(rect.width, text, false)) {

            scope (success) top += lineHeight * fontSize;

            // Stop if drawing below rect
            if (top > rect.height) break;

            // Text position from left
            double left = 0;

            const margin = (totalLineHeight - fontSize)/2;

            foreach (word; line.words) {

                const position = Vector2(rect.x + left, rect.y + top + margin);

                DrawTextEx(cast() font, word.text.toStringz, position, fontSize,
                    fontSize * charSpacing, textColor);

                left += word.width + fontSize * wordSpacing;

            }

        }

    }

    /// Split the text into multiple lines in order to fit within given width.
    ///
    /// Params:
    ///     width         = Container width the text should fit in.
    ///     text          = Text to wrap.
    ///     lineFeedsOnly = If true, this should only wrap the text on line feeds.
    TextLine[] wrapText(double width, string text, bool lineFeedsOnly) const {

        const spaceSize = fontSize * wordSpacing;

        auto result = [TextLine()];

        /// Get width of the given word.
        float wordWidth(string wordText) {

            return MeasureTextEx(cast() font, wordText.toStringz, fontSize, fontSize * charSpacing).x;

        }

        TextLine.Word[] words;

        auto whitespaceSplit = text[]
            .splitter!((a, string b) => [' ', '\n'].canFind(a), Yes.keepSeparators)(" ");

        // Pass 1: split on words, calculate minimum size
        foreach (chunk; whitespaceSplit.chunks(2)) {

            const wordText = chunk.front;
            const size = wordWidth(wordText);

            chunk.popFront;
            const feed = chunk.empty
                ? false
                : chunk.front == "\n";

            // Push the word
            words ~= TextLine.Word(wordText, size, feed);

            // Update minimum size
            if (size > width) width = size;

        }

        // Pass 2: calculate total size
        foreach (word; words) {

            scope (success) {

                // Start a new line if this words is followed by a line feed
                if (word.lineFeed) result ~= TextLine();

            }

            auto lastLine = &result[$-1];

            // If last line is empty
            if (lastLine.words == []) {

                // Append to it immediately
                lastLine.words ~= word;
                lastLine.width += word.width;
                continue;

            }


            // Check if this word can fit
            if (lineFeedsOnly || lastLine.width + spaceSize + word.width <= width) {

                // Push it to this line
                lastLine.words ~= word;
                lastLine.width += spaceSize + word.width;

            }

            // It can't
            else {

                // Push it to a new line
                result ~= TextLine([word], word.width);

            }

        }

        return result;

    }

    /// Draw the background
    void drawBackground(Rectangle rect) const {

        DrawRectangleRec(rect, backgroundColor);

    }

}

/// `wrapText` result.
struct TextLine {

    struct Word {

        string text;
        float width;
        bool lineFeed;  // Word is followed by a line feed.

    }

    /// Words on this line.
    Word[] words;

    /// Width of the line (including spaces).
    float width = 0;

}

/// Define style fields for a node and let them be affected by themes.
/// params:
///     names = A list of styles to define.
mixin template DefineStyles(names...) {

    import std.traits : BaseClassesTuple;
    import std.meta : Filter;

    import glui.utils : StaticFieldNames;

    private alias Parent = BaseClassesTuple!(typeof(this))[0];
    private alias MemberType(alias member) = typeof(__traits(getMember, Parent, member));

    private enum isStyleKey(alias member) = is(MemberType!member == immutable(StyleKey));
    private alias StyleKeys = Filter!(isStyleKey, StaticFieldNames!Parent);

    // Inherit style keys
    static foreach (field; StyleKeys) {

        mixin("static immutable StyleKey " ~ field ~ ";");

    }

    // Local styles
    static foreach(i, name; names) {

        // Only check even names
        static if (i % 2 == 0) {

            // Define the key
            mixin("static immutable StyleKey " ~ name ~ "Key;");

            // Define the value
            mixin("protected Style " ~ name ~ ";");

        }

    }

    // Load styles
    override protected void reloadStyles() {

        import std.stdio;
        import std.traits;

        super.reloadStyles();

        // I have no idea why is this foreach actually necessary. I tried removing it, but it breaks everything.
        // The default value in the second foreach should be enough. It's not. Might as well try removing the other
        // foreach and adding default value functionality here; probably a better option.
        static foreach (name; StyleKeys) {{

            if (auto style = &mixin(name) in theme) {

                mixin("this." ~ name[0 .. $-3]) = cast() *style;

            }

        }}

        static foreach (i, name; names) {

            static if (i % 2 == 0) {

                mixin(name) = cast() theme.get(&mixin(name ~ "Key"), mixin(names[i+1]));

            }

        }

    }

}
