///
module glui.space;

import raylib;

import std.math;
import std.range;
import std.string;
import std.traits;
import std.algorithm;

import glui.node;
import glui.style;
import glui.utils;
import glui.children;

@safe:

/// Make a new vertical space
GluiSpace vspace(T...)(T args) {

    return new GluiSpace(args);

}

/// Make a new horizontal space
GluiSpace hspace(T...)(T args) {

    auto frame = new GluiSpace(args);
    frame.directionHorizontal = true;

    return frame;

}

/// This is a space, basic container for other nodes.
///
/// Space only acts as a container and doesn't implement styles and doesn't take focus. It can be very useful to build
/// overlaying nodes, eg. with `GluiOnionFrame`.
class GluiSpace : GluiNode {

    mixin DefineStyles;

    /// Children of this frame.
    Children children;

    /// Defines in what directions children of this frame should be placed.
    ///
    /// If true, children are placed horizontally, if false, vertically.
    bool directionHorizontal;

    private {

        /// Denominator for content sizing.
        uint denominator;

        /// Space reserved for shrinking elements.
        uint reservedSpace;

    }

    // Generate constructors
    static foreach (index; 0 .. BasicNodeParamLength) {

        this(BasicNodeParam!index params, GluiNode[] nodes...) {

            super(params);
            this.children ~= nodes;

        }

    }

    /// Add children.
    pragma(inline, true)
    void opOpAssign(string operator : "~", T)(T nodes) {

        children ~= nodes;

    }

    protected override void resizeImpl(Vector2 available) {

        import std.algorithm : max, map, fold;

        // Reset size
        minSize = Vector2(0, 0);
        reservedSpace = 0;
        denominator = 0;

        // Ignore the rest if there's no children
        if (!children.length) return;

        // Construct a new node list
        GluiNode[] nodeList;
        foreach (child; children) {

            // This node expands and isn't hidden
            if (child.layout.expand && !child.hidden) {

                // Append
                nodeList ~= child;

                // Add to the denominator
                denominator += child.layout.expand;

            }

            // Prepend to ensure the child will be checked first
            else nodeList = child ~ nodeList;

        }

        // Calculate the size of each child
        foreach (child; nodeList) {

            // Inherit root
            child.tree = tree;

            // Inherit theme
            if (child.theme is null) {

                child.theme = theme;

            }

            child.resize(childSpace(child, available));
            minSize = childPosition(child, minSize);

            // If this child doesn't expand
            if (child.layout.expand == 0) {

                // Reserve space for it
                reservedSpace += directionHorizontal
                    ? cast(uint) child.minSize.x
                    : cast(uint) child.minSize.y;

            }

        }

    }

    protected override void drawImpl(Rectangle, Rectangle area) {

        auto position = Vector2(area.x, area.y);

        drawChildren((child) {

            // Get params
            const size = childSpace(child, Vector2(area.width, area.height));
            const rect = Rectangle(
                position.x, position.y,
                size.x, size.y
            );

            // Draw the child
            child.draw(rect);

            // Offset position
            if (directionHorizontal) position.x += cast(int) size.x;
            else position.y += cast(int) size.y;

        });

    }

    /// Iterate over every child and perform the painting function. Will automatically remove nodes queued for removal.
    protected void drawChildren(void delegate(GluiNode) @safe painter) {

        GluiNode[] leftovers;

        children.lock();
        scope (exit) children.unlock();

        // Draw each child and get rid of removed children
        auto range = children[]
            .filter!"!a.toRemove"
            .tee!((node) => painter(node));

        () @trusted {

            // Process the children and move them back to the original array
            auto leftovers = range.moveAll(children.forceMutable);

            // Adjust the array size
            children.forceMutable.length -= leftovers.length;

        }();

    }

    protected override bool hoveredImpl(Rectangle, Vector2) const {

        return false;

    }

    protected override const(Style) pickStyle() const {

        return null;

    }

    /// Params:
    ///     child     = Child to calculate.
    ///     previous  = Previous position.
    private Vector2 childPosition(const GluiNode child, Vector2 previous) const {

        import std.algorithm : max;

        // Horizontal
        if (directionHorizontal) {

            return Vector2(
                previous.x + child.minSize.x,
                max(minSize.y, child.minSize.y),
            );

        }

        // Vertical
        else return Vector2(
            max(minSize.x, child.minSize.x),
            previous.y + child.minSize.y,
        );

    }

    /// Get space for a child.
    /// Params:
    ///     child     = Child to place
    ///     available = Available space
    private Vector2 childSpace(const GluiNode child, Vector2 available) const
    in(
        child.hidden || child.layout.expand <= denominator,
        format!"Nodes %s/%s sizes are out of date, call updateSize after updating the tree or layout (%s/%s)"(
            typeid(this), typeid(child), child.layout.expand, denominator,
        )
    )
    out(
        r; [r.tupleof].all!isFinite,
        format!"space: child %s given invalid size %s. available = %s, expand = %s, denominator = %s, reserved = %s"(
            typeid(child), r, available, child.layout.expand, denominator, reservedSpace
        )
    )
    do {

        // Hidden, give it no space
        if (child.hidden) return Vector2();

        // Horizontal
        if (directionHorizontal) {

            const avail = (available.x - reservedSpace);

            return Vector2(
                child.layout.expand
                    ? avail * child.layout.expand / denominator
                    : child.minSize.x,
                available.y,
            );

        }

        // Vertical
        else {

            const avail = (available.y - reservedSpace);

            return Vector2(
                available.x,
                child.layout.expand
                    ? avail * child.layout.expand / denominator
                    : child.minSize.y,
            );

        }

    }

}
