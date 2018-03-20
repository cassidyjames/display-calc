/*
* Copyright (c) 2018 Cassidy James Blaede (https://cassidyjames.com)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Cassidy James Blaede <c@ssidyjam.es>
*/

public class MainWindow : Gtk.Window {
  private const int DEFAULT_ASPECT_WIDTH = 16;
  private const int DEFAULT_ASPECT_HEIGHT = 9;

  private const int INTERNAL_IDEAL_DPI = 140;
  private const int INTERNAL_IDEAL_RANGE = 16;
  private const int INTERNAL_UNCLEAR_RANGE = 14;

  private const int EXTERNAL_IDEAL_DPI = 120;
  private const int EXTERNAL_IDEAL_RANGE = 30;
  private const int EXTERNAL_UNCLEAR_RANGE = 20;

  private const double INCHES_INFER_EXTERNAL = 18;
  private const int DPI_INFER_HIDPI = 192; // According to GNOME

  private enum Range {
    LOW,
    LODPI_LOW,
    LODPI_IDEAL,
    LODPI_HIGH,
    HIDPI_LOW,
    HIDPI_IDEAL,
    HIDPI_HIGH,
    HIGH,
    UNCLEAR,
    INVALID;

    public string title () {
      switch (this) {
        case LOW:
          return _("Very Low DPI");

        case LODPI_LOW:
          return _("Fairly Low DPI");

        case LODPI_IDEAL:
          return _("Ideal for LoDPI");

        case LODPI_HIGH:
        case HIDPI_LOW:
        case UNCLEAR:
          return _("Potentially Problematic");

        case HIDPI_IDEAL:
          return _("Ideal for HiDPI");

        case HIDPI_HIGH:
          return _("Fairly High for HiDPI");

        case HIGH:
          return _("Too High DPI");

        case INVALID:
          return _("Analyze a Display");

        default:
            assert_not_reached();
      }
    }

    public string description () {
      switch (this) {
        case LOW:
          return _("Text and UI are likely to be too big for typical viewing distances. Avoid if possible.");

        case LODPI_LOW:
          return _("Text and UI might be too big for typical viewing distances, but it's largely up to user preference and physical distance from the display.");

        case LODPI_IDEAL:
          return _("Not HiDPI, but a nice sweet spot. Text and UI should be legible at typical viewing distances.");

        case LODPI_HIGH:
          return _("Relatively high resolution, but not quite HiDPI. Text and UI may be too small by default, but forcing HiDPI would make them appear too large. The experience may be slightly improved by increasing the text size.");

        case HIDPI_LOW:
          return _("HiDPI by default, but text and UI may appear too large. Turning off HiDPI and increasing the text size might help.");

        case HIDPI_IDEAL:
          return _("Crisp HiDPI text and UI along with a readable size at typical viewing distances. This is the jackpot.");

        case HIDPI_HIGH:
          return _("Text and UI are likely to appear too small for typical viewing distances. Increasing the text size may help.");

        case HIGH:
          return _("Text and UI will appear too small for typical viewing distances.");

        case UNCLEAR:
          return _("This display is in a very tricky range and is not likely to work well with integer scaling out of the box.");

        case INVALID:
          return _("Enter details about a display to analyze it.");

        default:
            assert_not_reached();
      }
    }

    public string icon () {
      switch (this) {
        case LOW:
        case HIGH:
          return "dialog-error";

        case LODPI_LOW:
        case LODPI_HIGH:
        case HIDPI_LOW:
        case HIDPI_HIGH:
        case UNCLEAR:
          return "dialog-warning";

        case LODPI_IDEAL:
        case HIDPI_IDEAL:
          return "process-completed";

        case INVALID:
          return "dialog-information";

        default:
            assert_not_reached();
      }
    }
  }

  private int aspect_width = DEFAULT_ASPECT_WIDTH;
  private int aspect_height = DEFAULT_ASPECT_HEIGHT;

  private double inches = 0.0;
  private int width = 0;
  private int height = 0;
  private bool is_default_display_type = true;
  private bool is_default_width = true;
  private bool is_default_height = true;
  private string direction = "";
  private int scaling_factor = 1;

  private Gtk.Image diagram;
  private Gtk.Entry diag_entry;
  private Gtk.Entry width_entry;
  private Gtk.Entry height_entry;
  private Gtk.Label dpi_result_label;
  private Gtk.Label logical_resolution_label;
  private Gtk.Label aspect_result_label;
  private Granite.Widgets.ModeButton type_modebutton;
  private Gtk.Label range_title_label;
  private Gtk.Label range_description_label;
  private Gtk.Image range_icon;
  private Gtk.LevelBar range_bar;
  private Gtk.Label range_bar_min;
  private Gtk.Label range_bar_max;
  private Range range;
  private Utils.DisplayType display_type;

  public MainWindow (Gtk.Application application) {
    Object (
      application: application,
      border_width: 0,
      icon_name: "com.github.cassidyjames.dippi",
      resizable: false,
      title: _("Dippi"),
      window_position: Gtk.WindowPosition.CENTER
    );
  }

  construct {
    weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
    default_theme.add_resource_path ("/com/github/cassidyjames/dippi");

    var header = new Gtk.HeaderBar ();
    header.show_close_button = true;
    var header_context = header.get_style_context ();
    header_context.add_class ("titlebar");
    header_context.add_class ("default-decoration");
    header_context.add_class (Gtk.STYLE_CLASS_FLAT);

    diagram = new Gtk.Image.from_icon_name ("com.github.cassidyjames.dippi", Gtk.IconSize.INVALID);
    diagram.pixel_size = 128;
    diagram.margin_bottom = 12;

    var diag_label = new Gtk.Label (_("Diagonal size:"));
    diag_label.halign = Gtk.Align.END;

    diag_entry = new Gtk.Entry();
    diag_entry.max_length = 5;
    diag_entry.max_width_chars = 5;
    diag_entry.width_chars = 5;
    diag_entry.focus_in_event.connect ((event) => {
      direction = "diagonal";
      set_display_icon ();
      return focus_in_event (event);
    });

    var res_label = new Gtk.Label (_("Resolution:"));
    res_label.halign = Gtk.Align.END;

    width_entry = new Gtk.Entry();
    width_entry.max_length = 5;
    width_entry.max_width_chars = 5;
    width_entry.width_chars = 5;
    width_entry.focus_in_event.connect ((event) => {
      direction = "horizontal";
      set_display_icon ();
      return focus_in_event (event);
    });

    height_entry = new Gtk.Entry();
    height_entry.max_length = 5;
    height_entry.max_width_chars = 5;
    height_entry.width_chars = 5;
    height_entry.focus_in_event.connect ((event) => {
      direction = "vertical";
      set_display_icon ();
      return focus_in_event (event);
    });

    var x_label = new Gtk.Label (_("×"));
    var px_label = new Gtk.Label (_("px"));

    var inches_label = new Gtk.Label (_("inches"));
    inches_label.halign = Gtk.Align.START;

    var type_label = new Gtk.Label (_("Type:"));
    type_label.halign = Gtk.Align.END;

    type_modebutton = new Granite.Widgets.ModeButton ();
    type_modebutton.append_text (Utils.DisplayType.INTERNAL.to_string ());
    type_modebutton.append_text (Utils.DisplayType.EXTERNAL.to_string ());

    aspect_result_label = new Gtk.Label (null);
    aspect_result_label.halign = Gtk.Align.START;
    aspect_result_label.selectable = true;

    dpi_result_label = new Gtk.Label (null);
    dpi_result_label.halign = Gtk.Align.START;
    dpi_result_label.selectable = true;

    logical_resolution_label = new Gtk.Label (null);
    logical_resolution_label.expand = true;
    logical_resolution_label.halign = Gtk.Align.START;
    logical_resolution_label.selectable = true;

    range_icon = new Gtk.Image.from_icon_name (Range.INVALID.icon (), Gtk.IconSize.DIALOG);
    range_icon.margin_bottom = 12;
    range_icon.valign = Gtk.Align.START;

    range_title_label = new Gtk.Label (null);
    range_title_label.wrap = true;
    range_title_label.halign = Gtk.Align.START;
    range_title_label.selectable = true;
    range_title_label.xalign = 0;
    range_title_label.valign = Gtk.Align.END;
    range_title_label.get_style_context ().add_class ("h2");
    range_title_label.label = Range.INVALID.title ();

    range_description_label = new Gtk.Label (null);
    range_description_label.margin_bottom = 12;
    range_description_label.max_width_chars = 50;
    range_description_label.selectable = true;
    range_description_label.wrap = true;
    range_description_label.xalign = 0;
    range_description_label.valign = Gtk.Align.START;
    range_description_label.label = Range.INVALID.description ();

    range_bar = new Gtk.LevelBar ();
    range_bar.margin_start = range_bar.margin_end = 6;
    range_bar.hexpand = true;
    range_bar.valign = Gtk.Align.CENTER;

    range_bar_min = new Gtk.Label (null);
    range_bar_max = new Gtk.Label (null);

    diag_entry.changed.connect (() => {
      inches = double.parse (diag_entry.get_text ());
      assess_dpi (
        recalculate_dpi (inches, width, height),
        infer_display_type (inches)
      );
    });

    width_entry.changed.connect (() => {
      width = int.parse (width_entry.get_text ());

      is_default_width = false;

      recalculate_aspect (width, height);
      assess_dpi (
        recalculate_dpi (inches, width, height),
        display_type
      );

      if (!height_entry.has_focus && (is_default_height || height == 0)) {
        double calculated_height = Math.round(width * DEFAULT_ASPECT_HEIGHT / DEFAULT_ASPECT_WIDTH);
        height_entry.text = (calculated_height).to_string ();
        is_default_height = true;
      }
    });

    height_entry.changed.connect (() => {
      height = int.parse (height_entry.get_text ());

      is_default_height = false;

      recalculate_aspect (width, height);
      assess_dpi (
        recalculate_dpi (inches, width, height),
        display_type
      );

      if (!width_entry.has_focus && (is_default_width || width == 0)) {
        double calculated_width = Math.round(height * DEFAULT_ASPECT_WIDTH / DEFAULT_ASPECT_HEIGHT);
        width_entry.text = (calculated_width).to_string ();
        is_default_width = true;
      }
    });

    type_modebutton.mode_changed.connect (() => {
      switch (type_modebutton.selected) {
        case 0:
          display_type = Utils.DisplayType.INTERNAL;
          break;

        case 1:
          display_type = Utils.DisplayType.EXTERNAL;
          break;

        default:
          assert_not_reached();
      }

      assess_dpi (Utils.dpi (inches, width, height), display_type);
      set_display_icon ();
    });

    var data_grid = new Gtk.Grid ();
    data_grid.column_spacing = 6;
    data_grid.margin = 24;
    data_grid.margin_top = 0;
    data_grid.row_spacing = 6;
    data_grid.get_style_context ().add_class ("data-grid");

    data_grid.attach (diagram,         0, 0, 5, 1);
    data_grid.attach (diag_label,      0, 1, 1, 1);
    data_grid.attach (diag_entry,      1, 1, 1, 1);
    data_grid.attach (inches_label,    2, 1, 2, 1);
    data_grid.attach (res_label,       0, 2, 1, 1);
    data_grid.attach (width_entry,     1, 2, 1, 1);
    data_grid.attach (x_label,         2, 2, 1, 1);
    data_grid.attach (height_entry,    3, 2, 1, 1);
    data_grid.attach (px_label,        4, 2, 1, 1);
    data_grid.attach (type_label,      0, 3, 1, 1);
    data_grid.attach (type_modebutton, 1, 3, 4, 1);

    var range_grid = new Gtk.Grid ();
    range_grid.attach (range_bar_min, 0, 0, 1, 1);
    range_grid.attach (range_bar,     1, 0, 1, 1);
    range_grid.attach (range_bar_max, 2, 0, 1, 1);

    var assessment_grid = new Gtk.Grid ();
    assessment_grid.column_spacing = 12;
    assessment_grid.halign = Gtk.Align.START;
    assessment_grid.margin = 12;
    assessment_grid.margin_top = 48;
    assessment_grid.row_spacing = 6;
    assessment_grid.valign = Gtk.Align.START;
    assessment_grid.get_style_context ().add_class ("assessment-grid");

    assessment_grid.attach (range_icon,               0, 0, 1, 2);
    assessment_grid.attach (range_title_label,        1, 0, 3, 1);
    assessment_grid.attach (range_description_label,  1, 1, 3, 1);
    assessment_grid.attach (aspect_result_label,      1, 2, 1, 1);
    assessment_grid.attach (dpi_result_label,         2, 2, 1, 1);
    assessment_grid.attach (logical_resolution_label, 3, 2, 1, 1);
    assessment_grid.attach (range_grid,               0, 3, 4, 1);

    var main_layout = new Gtk.Grid ();
    main_layout.column_spacing = 6;
    main_layout.height_request = 258;
    main_layout.row_spacing = 6;
    main_layout.width_request = 710;
    main_layout.attach (data_grid,       0, 0, 1, 1);
    main_layout.attach (assessment_grid, 1, 0, 1, 1);

    diag_entry.grab_focus ();

    get_style_context ().add_class ("dippi");
    get_style_context ().add_class ("rounded");
    set_titlebar (header);
    add (main_layout);
  }

  private int recalculate_dpi (double inches, int width, int height) {
    if (inches > 0 && width > 0 && height > 0) {
      int calculated_dpi = Utils.dpi (inches, width, height);

      if (calculated_dpi >= DPI_INFER_HIDPI) {
        scaling_factor = 2;
      } else {
        scaling_factor = 1;
      }

      dpi_result_label.label = _("%d DPI").printf (calculated_dpi);

      recalculate_logical_resolution (width, height, calculated_dpi);
      return calculated_dpi;
    }

    dpi_result_label.label = "";
    return 0;
  }

  private void recalculate_aspect (int width, int height) {
    if (width > 0 && height > 0) {
      aspect_width = width / Utils.greatest_common_divisor (width, height);
      aspect_height = height / Utils.greatest_common_divisor (width, height);
      aspect_result_label.label = (aspect_width).to_string () + _(":") + (aspect_height).to_string ();
    }
  }

  private void recalculate_logical_resolution (int width, int height, int dpi) {
    int logical_width = (int)(width / scaling_factor);
    int logical_height = (int)(height / scaling_factor);

    logical_resolution_label.label = "%d×%d@%dx".printf (
      logical_width,
      logical_height,
      scaling_factor
    );
  }

  private void assess_dpi (double calculated_dpi, Utils.DisplayType display_type) {
    int ideal_dpi = INTERNAL_IDEAL_DPI;
    int ideal_range = INTERNAL_IDEAL_RANGE;
    int unclear_range = INTERNAL_UNCLEAR_RANGE;

    if (display_type == Utils.DisplayType.EXTERNAL ) {
      ideal_dpi = EXTERNAL_IDEAL_DPI;
      ideal_range = EXTERNAL_IDEAL_RANGE;
      unclear_range = EXTERNAL_UNCLEAR_RANGE;
    }

    if ( inches == 0 || width == 0 || height == 0 ) {
      range = Range.INVALID;
    }

    else if (calculated_dpi < ideal_dpi - ideal_range - INTERNAL_UNCLEAR_RANGE) {
      range = Range.LOW;
    }

    else if (calculated_dpi < ideal_dpi - ideal_range) {
      range = Range.LODPI_LOW;
    }

    else if (calculated_dpi <= ideal_dpi + ideal_range) {
      range = Range.LODPI_IDEAL;
    }

    else if (calculated_dpi <= ideal_dpi + ideal_range + unclear_range) {
      range = Range.LODPI_HIGH;
    }

    else if (calculated_dpi < DPI_INFER_HIDPI) {
      range = Range.UNCLEAR;
    }

    else if (calculated_dpi < (ideal_dpi - ideal_range - unclear_range) * 2) {
      range = Range.UNCLEAR;
    }

    else if (calculated_dpi < (ideal_dpi - ideal_range) * 2) {
      range = Range.HIDPI_LOW;
    }

    else if (calculated_dpi <= (ideal_dpi + ideal_range) * 2) {
      range = Range.HIDPI_IDEAL;
    }

    else if (calculated_dpi <= (ideal_dpi + ideal_range + unclear_range) * 2) {
      range = Range.HIDPI_HIGH;
    }

    else if (calculated_dpi > (ideal_dpi + ideal_range + unclear_range) * 2) {
      range = Range.HIGH;
    }

    else {
      range = Range.INVALID;
    }

    range_icon.icon_name = range.icon ();
    range_title_label.label = range.title ();
    range_description_label.label = range.description ();
    range_bar.min_value = (ideal_dpi - ideal_range - unclear_range) * scaling_factor;
    range_bar.max_value = (ideal_dpi + ideal_range + unclear_range) * scaling_factor;
    range_bar.add_offset_value ("low", (ideal_dpi - ideal_range) * scaling_factor);
    range_bar.add_offset_value ("high", (ideal_dpi + ideal_range) * scaling_factor);

    range_bar_min.label = range_bar.min_value.to_string ();
    range_bar_max.label = range_bar.max_value.to_string ();

    if (calculated_dpi > range_bar.max_value) {
      range_bar.value = range_bar.max_value;
    } else if (calculated_dpi < range_bar.min_value) {
      range_bar.value = range_bar.min_value;
    } else {
      range_bar.value = calculated_dpi;
    }
  }

  private Utils.DisplayType infer_display_type (double inches) {
    is_default_display_type = true;

    if (inches < INCHES_INFER_EXTERNAL) {
      display_type = Utils.DisplayType.INTERNAL;
      type_modebutton.selected = 0;
    } else {
      display_type = Utils.DisplayType.EXTERNAL;
      type_modebutton.selected = 1;
    }

    return display_type;
  }

  private void set_display_icon () {
    diagram.icon_name = "display-measure-" + direction + display_type.icon_suffix ();
  }
}
