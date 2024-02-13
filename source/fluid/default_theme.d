module fluid.default_theme;

import fluid.node;
import fluid.frame;
import fluid.style;
import fluid.button;
import fluid.backend;
import fluid.text_input;
import fluid.scroll_input;

/// Theme with no properties set.
///
/// Unlike `Theme.init` or `null`, which will be replaced by fluidDefaultTheme or the parent's theme, this can be used as
/// a valid theme for any node. This makes it useful for automatic tests, since it has guaranteed no margins, padding,
/// or other properties that may confuse the tester.
Theme nullTheme;

/// Default theme that Fluid will use if no theme is supplied. It is a very simple theme that does the minimum to make
/// the role of each node understandable.
Theme fluidDefaultTheme;

static this() {

    with (Rule) {

        nullTheme.add(
            rule!Node(),
        );

        fluidDefaultTheme.add(
            rule!Node(
                textColor = color("#000"),
            ),
            rule!Frame(
                backgroundColor = color("#fff"),
            ),
            rule!Button(
                backgroundColor = color("#eee"),
                mouseCursor = FluidMouseCursor.pointer,
                margin.sideY = 2,
                padding.sideX = 6,

                when!"a.isHovered"(backgroundColor = color("#ccc")),
                when!"a.isFocused"(backgroundColor = color("#ddd")),  // TODO use an outline for focus
                when!"a.isPressed"(backgroundColor = color("#aaa")),
                when!"a.isDisabled"(
                    textColor = color("000a"),
                    backgroundColor = color("eee5"),
                    // TODO disabled should apply opacity, and should work for every node
                ),
            ),
            rule!TextInput(
                backgroundColor = color("#fff"),
                borderStyle = colorBorder(color("#aaa")),
                mouseCursor = FluidMouseCursor.text,

                margin.sideY = 2,
                padding.sideX = 6,
                border.sideBottom = 2,

                when!"a.isEmpty"(textColor = color("#000a")),
                when!"a.isFocused"(borderStyle = colorBorder(color("#555"))),
                when!"a.isDisabled"(
                    textColor = color("#000a"),
                    backgroundColor = color("#fff5"),
                ),
            ),
            rule!ScrollInput(
                backgroundColor = color("#eee"),

            ),
            rule!ScrollInputHandle(
                backgroundColor = color("#aaa"),
                when!"a.isHovered"(backgroundColor = color("#888")),
                when!"a.isFocused"(backgroundColor = color("#777")),
                when!"a.isPressed"(backgroundColor = color("#555")),
                when!"a.isDisabled"(backgroundColor = color("#aaa5")),
            ),
            //rule!FileInput.unselectedStyleAdd.backgroundColor = color("fff"),
            //rule!FileInput.selectedStyleAdd.backgroundColor = color("ff512f"),
        );

    }

}
