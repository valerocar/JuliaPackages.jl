using Pkg
Pkg.activate(".")

using Dash, DashHtmlComponents, DashCoreComponents, DashBootstrapComponents

app = dash(external_stylesheets = [dbc_themes.COSMO])


input = dbc_inputgroup([
        dbc_inputgrouptext("Package"),
        dbc_input(placeholder = "name"),
        dbc_button("Search", color = "primary", className = "me-1"),
])

dp = dbc_inputgroup([
        dbc_inputgrouptext("Multiselect"),
        dcc_dropdown(
                id = "drop",
                style=Dict("width"=>"150px"),
                options = [(label = "PlotlyJS", value = "PlotlyJS"), (label = "Dash", value = "Dash")],
                value = "PlotlyJS"
        ),
])


dropdown_menu_items = [
    dbc_dropdownmenuitem("Deep thought", id = "dropdown-menu-item-1"),
    dbc_dropdownmenuitem("Hal", id = "dropdown-menu-item-2"),
    dbc_dropdownmenuitem(divider = true),
    dbc_dropdownmenuitem("Clear", id = "dropdown-menu-item-clear"),
];


input_group = dbc_inputgroup([
    dbc_dropdownmenu(dropdown_menu_items, label = "Generate"),
    dbc_input(id = "input-group-dropdown-input", placeholder = "name"),
]);


date_picker = dcc_datepickerrange(id = "dates")
date = dbc_inputgroup([dbc_inputgrouptext("Date range"), date_picker])
app.layout = dbc_container(
        [
                dbc_row([dbc_col(input, width = 5), dbc_col(date, width = 7)])
                dbc_row([dbc_col(dp, width = 5), dbc_col("Adios", width = 3)])
        ],
)

run_server(app, "0.0.0.0", debug = true)
