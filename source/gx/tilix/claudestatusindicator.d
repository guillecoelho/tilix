/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.claudestatusindicator;

import std.format;

import gtk.Box;
import gtk.Label;

import gx.i18n.l10n;
import gx.tilix.claudestatus;

class ClaudeStatusIndicator : Box {
private:
    Label dot;
    Label text;

public:
    this() {
        super(Orientation.HORIZONTAL, 4);
        dot = new Label("●");
        text = new Label("");
        add(dot);
        add(text);
        dot.show();
        text.show();
        setNoShowAll(true);
        hide();
    }

    void update(ClaudeSummary summary) {
        auto dotStyle = dot.getStyleContext();
        auto textStyle = text.getStyleContext();
        foreach (name; ["tilix-claude-working", "tilix-claude-waiting", "tilix-claude-idle"]) {
            dotStyle.removeClass(name);
            textStyle.removeClass(name);
        }

        if (summary.status == ClaudeStatus.NONE) {
            hide();
            return;
        }

        string label;
        string cssClass;
        final switch (summary.status) {
            case ClaudeStatus.NONE: assert(0);
            case ClaudeStatus.IDLE:
                label = _("Idle");
                cssClass = "tilix-claude-idle";
                break;
            case ClaudeStatus.WORKING:
                label = _("Working");
                cssClass = "tilix-claude-working";
                break;
            case ClaudeStatus.WAITING:
                label = _("Waiting");
                cssClass = "tilix-claude-waiting";
                break;
        }

        text.setText(label);
        dotStyle.addClass(cssClass);
        textStyle.addClass(cssClass);
        setTooltipText(summary.count > 1 ? format(_("%s in %d terminals"), label, summary.count) : label);
        show();
    }

    void setAngle(double angle) {
        text.setAngle(angle);
        setOrientation(angle == 0 ? Orientation.HORIZONTAL : Orientation.VERTICAL);
    }
}
