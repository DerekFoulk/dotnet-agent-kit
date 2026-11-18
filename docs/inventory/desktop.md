# Microsoft Learn inventory: WPF and Windows Forms guidance

Batch D-maui-desktop read the WPF and Windows Forms part of this set. The docs-desktop table of contents lists 1,602 pages. 39 were candidates. They produced WPF-001 to WPF-007 and WFM-001 to WFM-004. Every verdict was checked on 2026-11-17.

The page list for this set, with every page's guidance-wording score, is in `docs/inventory/desktop-pages.tsv`. Re-check with the `discover-guidance` skill.

| Page | Checked | Verdict |
|---|---|---|
| https://learn.microsoft.com/dotnet/desktop/winforms/advanced/how-to-enable-binaryformatter-clipboard-support | 2026-11-17 | covered by WFM-001 (its allow-list bullets aren't separate rules) |
| https://learn.microsoft.com/dotnet/desktop/winforms/advanced/how-to-retrieve-data-from-the-clipboard | 2026-11-17 | new rule WFM-001 |
| https://learn.microsoft.com/dotnet/desktop/winforms/advanced/properties-on-windows-forms-controls-that-support-accessibility-guidelines | 2026-11-17 | new rule WFM-003 |
| https://learn.microsoft.com/dotnet/desktop/winforms/advanced/walkthrough-creating-an-accessible-windows-based-application | 2026-11-17 | new rule WFM-003 |
| https://learn.microsoft.com/dotnet/desktop/winforms/controls-design/designer-properties-overview | 2026-11-17 | out of scope: designer tooling |
| https://learn.microsoft.com/dotnet/desktop/winforms/controls-design/usercontrol-guidelines | 2026-11-17 | out of scope: designer tooling |
| https://learn.microsoft.com/dotnet/desktop/winforms/controls/best-practices-for-scaling-the-windows-forms-datagridview-control | 2026-11-17 | new rule WFM-004 |
| https://learn.microsoft.com/dotnet/desktop/winforms/controls/best-practices-for-the-tablelayoutpanel-control | 2026-11-17 | out of scope: choice of layout control (UX) |
| https://learn.microsoft.com/dotnet/desktop/winforms/controls/cell-styles-in-the-windows-forms-datagridview-control | 2026-11-17 | covered by WFM-004 |
| https://learn.microsoft.com/dotnet/desktop/winforms/controls/how-to-set-default-cell-styles-for-the-windows-forms-datagridview-control | 2026-11-17 | covered by WFM-004 |
| https://learn.microsoft.com/dotnet/desktop/winforms/controls/implementing-virtual-mode-jit-data-loading-in-the-datagrid | 2026-11-17 | out of scope: one rarely used API (virtual-mode paging) |
| https://learn.microsoft.com/dotnet/desktop/winforms/controls/layout | 2026-11-17 | no guidance (descriptive) |
| https://learn.microsoft.com/dotnet/desktop/winforms/controls/sizing-options-in-the-windows-forms-datagridview-control | 2026-11-17 | new rule WFM-004 (one quote) |
| https://learn.microsoft.com/dotnet/desktop/winforms/controls/virtual-mode-in-the-windows-forms-datagridview-control | 2026-11-17 | no guidance (descriptive) |
| https://learn.microsoft.com/dotnet/desktop/winforms/forms/events | 2026-11-17 | new rule WFM-002 |
| https://learn.microsoft.com/dotnet/desktop/winforms/migration/clipboard-dataobject-net10 | 2026-11-17 | new rule WFM-001 |
| https://learn.microsoft.com/dotnet/desktop/winforms/security-in-windows-forms-overview | 2026-11-17 | out of scope: .NET Framework code access security / partial trust |
| https://learn.microsoft.com/dotnet/desktop/winforms/windows-forms-security | 2026-11-17 | out of scope: .NET Framework, a list of links |
| https://learn.microsoft.com/dotnet/desktop/wpf/advanced/application-startup-time | 2026-11-17 | new rule WPF-001 (its Ngen, ClickOnce and Authenticode advice is .NET Framework; not ruled) |
| https://learn.microsoft.com/dotnet/desktop/wpf/advanced/freezable-objects-overview | 2026-11-17 | new rule WPF-002 |
| https://learn.microsoft.com/dotnet/desktop/wpf/advanced/optimizing-performance-other-recommendations | 2026-11-17 | new rule WPF-003 |
| https://learn.microsoft.com/dotnet/desktop/wpf/advanced/optimizing-performance-text | 2026-11-17 | new rule WPF-003 (hyphenation and optimal paragraph; its TextBlock/Run/Label.Content items are headings with measurements, not ruled) |
| https://learn.microsoft.com/dotnet/desktop/wpf/advanced/performance-considerations-for-direct3d9-and-wpf-interoperability | 2026-11-17 | out of scope: Direct3D9 interop, Windows XP/Vista, rarely used |
| https://learn.microsoft.com/dotnet/desktop/wpf/advanced/typeconverters-and-xaml | 2026-11-17 | out of scope: custom type converters, rarely used API |
| https://learn.microsoft.com/dotnet/desktop/wpf/advanced/types-migrated-from-wpf-to-system | 2026-11-17 | out of scope: .NET Framework 4 migration note |
| https://learn.microsoft.com/dotnet/desktop/wpf/advanced/use-automatic-layout-overview | 2026-11-17 | new rule WPF-004 |
| https://learn.microsoft.com/dotnet/desktop/wpf/advanced/wpf-globalization-and-localization-overview | 2026-11-17 | new rule WPF-004 (its localization-tool steps are how-to, not ruled) |
| https://learn.microsoft.com/dotnet/desktop/wpf/advanced/xaml-syntax-in-detail | 2026-11-17 | no guidance (language reference) |
| https://learn.microsoft.com/dotnet/desktop/wpf/controls/control-authoring-overview | 2026-11-17 | new rule WPF-005 |
| https://learn.microsoft.com/dotnet/desktop/wpf/controls/creating-a-control-that-has-a-customizable-appearance | 2026-11-17 | new rule WPF-006 |
| https://learn.microsoft.com/dotnet/desktop/wpf/controls/guidelines-for-designing-stylable-controls | 2026-11-17 | new rule WPF-006 |
| https://learn.microsoft.com/dotnet/desktop/wpf/controls/listview | 2026-11-17 | out of scope: one control's quirks |
| https://learn.microsoft.com/dotnet/desktop/wpf/properties/custom-dependency-properties | 2026-11-17 | new rule WPF-005 |
| https://learn.microsoft.com/dotnet/desktop/wpf/properties/safe-constructor-patterns-for-dependencyobjects | 2026-11-17 | new rule WPF-005 |
| https://learn.microsoft.com/dotnet/desktop/wpf/windows/dialog-boxes-overview | 2026-11-17 | out of scope: dialog UX design choices (DO/DON'T list; the lead may reverse) |
| https://learn.microsoft.com/dotnet/desktop/xaml-services/define-custom-types | 2026-11-17 | out of scope: authoring custom XAML types, rarely used API |
| https://learn.microsoft.com/dotnet/desktop/xaml-services/security-considerations | 2026-11-17 | new rule WPF-007 |
| https://learn.microsoft.com/dotnet/desktop/xaml-services/type-converters-overview | 2026-11-17 | out of scope: custom type converters, rarely used API |
| https://learn.microsoft.com/dotnet/desktop/xaml-services/xname-directive | 2026-11-17 | out of scope: trivia |
