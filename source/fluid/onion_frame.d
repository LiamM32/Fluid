///
module fluid.onion_frame;

import fluid.frame;
import fluid.utils;
import fluid.style;
import fluid.backend;


@safe:


/// An onion frame places its children as layers, drawing one on top of the other, instead of on the side.
///
/// Children are placed in order of drawing — the last child will be drawn last, and so, will appear on top.
alias onionFrame = simpleConstructor!FluidOnionFrame;

/// ditto
class FluidOnionFrame : FluidFrame {

    mixin DefineStyles;

    this(T...)(T args) {

        super(args);

    }

    protected override void resizeImpl(Vector2 available) {

        import std.algorithm : max;

        minSize = Vector2(0, 0);

        // Check each child
        foreach (child; children) {

            // Resize the child
            child.resize(tree, theme, available);

            // Update minSize
            minSize.x = max(minSize.x, child.minSize.x);
            minSize.y = max(minSize.y, child.minSize.y);

        }

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawBackground(tree.io, outer);

        foreach (child; filterChildren) {

            child.draw(inner);

        }

    }

}

///
unittest {

    import fluid;

    auto myFrame = onionFrame(

        // Draw an image
        imageView("logo.png"),

        // Draw a label in the middle of the frame
        label(
            layout!(1, "center"),
            "Hello, Fluid!"
        ),

    );

}

unittest {

    import fluid.label;
    import fluid.structs;
    import fluid.image_view;

    FluidImageView view;
    FluidLabel[2] labels;

    auto io = new HeadlessBackend;
    auto root = onionFrame(

        view = imageView("logo.png"),

        labels[0] = label(
            "Hello, Fluid!"
        ),

        labels[1] = label(
            layout!(1, "center"),
            "Hello, Fluid! This text should fit the image."
        ),

    );

    root.theme = nullTheme.makeTheme!q{
        FluidLabel.styleAdd.textColor = color!"000";
    };
    root.io = io;
    root.draw();

    // imageView
    io.assertTexture(view.texture, Vector2(0, 0), color!"fff");

    // First label
    io.assertTexture(labels[0].text.texture, Vector2(0, 0), color!"000");

    // TODO onionFrame should perform shrink-expand ordering similarly to `space`. The last label should wrap.

}
