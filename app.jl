using Pkg
Pkg.activate(".")

using Dash, DashHtmlComponents, DashCoreComponents, DashBootstrapComponents
using Statistics, DataFrames, CSVFiles
using Dates
import TOML

include("utils.jl")


# App begins
df = load_dataframe()

app = dash(external_stylesheets = [dbc_themes.COSMO])
app.title = "Julia Packages Requests"

description = dcc_markdown("Hello")

title = dbc_row(
    dbc_col(
        dbc_alert(
            color = "primary",
            html_center(
                html_div(
                    style = Dict("vertical-alight" => "middle"),
                    html_h1("Julia Packages Requests"),
                ),
            ),
            className = "bmi-jumbotron",
        ),
    ),
    className = "mt-3",
)

info_card = dbc_card(
    [
        dbc_cardheader("Requests Statistics")
        dbc_cardbody([html_div(id = "info-data", [html_p("Info Data")])])
    ],
    className = "card-tiny",
)

ttip = dbc_tooltip(
"Enter a Julia package name and press the search button",
target = "hola")

tabs = dbc_row(
    [
        dbc_col(
            html_div([
                dbc_tabs(
                    [
                        dbc_tab(label = "Users", tab_id = "user",id="hola"),
                        dbc_tab(label = "CI runs", tab_id = "ci"),
                    ],
                    id = "tabs",
                    active_tab = "user",
                ),
                html_div(id = "graph-content")
            ]),
            width = 8,
        )
        dbc_col(info_card, width = 4)
    ],
);


date_picker = dcc_datepickerrange(id = "dates", start_date = df."date"[begin], end_date = df."date"[end])





date_input = dbc_inputgroup([dbc_inputgrouptext(id="date-range","Date range"), date_picker,
dbc_tooltip(
"Select a date range for the request's data",
target = "date-range")])

search_input = dbc_inputgroup([
    dbc_inputgrouptext("Package",id="package-label"),
    dbc_input(id = "search-input", placeholder = "name"),
    dbc_tooltip(
    "Enter a Julia package name and press the search button",
    target = "package-label"),
    dbc_button("Search", color = "primary", id = "search-button"),
])


drop = dcc_dropdown(
    id = "drop",
    options = [(label = "PlotlyJS", value = "PlotlyJS")],
    style=Dict("width"=>"300px"),
    multi = true,
    value = nothing,
)

packages_input = dbc_row([
    dbc_col(search_input, width = 4),
    dbc_col(dbc_inputgroup([dbc_inputgrouptext("Select",id="multi"), drop]), width = 8),
    dbc_tooltip(
    "Select one or more of the searched package(s) to render",
    target = "multi")
])



drop_input = dbc_row(dbc_col(date_input, width = 6))
opts = []

callback!(
    app,
    Output("drop", "options"),
    Output("drop", "value"),
    Output("search-input", "value"),
    Input("search-button", "n_clicks"),
    State("search-input", "value"),
) do clicks, input_value
    value = input_value
    if value !== nothing
        value = split(input_value, ".")[1] # To strip .jl part
    end
    package_df = package_dataframe(value)
    if package_df === nothing
        return opts, nothing, ""
    end
    append!(opts, [(label = value, value = value)])
    opts_set = Set(opts)
    opts_new = [o for o in opts_set]
    opts_new, value, ""
end

checks = dbc_checklist(
    id = "checks",
    options = [
        Dict("label" => "Cumulative", "value" => "CU"),
        Dict("label" => "Regression Line", "value" => "RL"),
        Dict("label" => "Seven days moving averages", "value" => "MA"),
    ],
    value = [],
    labelStyle = Dict("display" => "inline-block"),
)

callback!(
    app,
    Output("graph-content", "children"),
    Output("info-data", "children"),
    Input("tabs", "active_tab"),
    Input("drop", "value"),
    Input("dates", "start_date"),
    Input("dates", "end_date"),
    Input("checks", "value"),
) do at, options, sd, ed, check_vals
    if at == "user"
        figure, info = plot_graphs(options, check_vals, "user", start_date = sd, end_date = ed)
        graph = dcc_graph(id = "graph_us", figure = figure)
        return graph, info
    elseif at == "ci"
        figure, info = plot_graphs(options, check_vals, "ci", start_date = sd, end_date = ed)
        graph = dcc_graph(id = "graph_ci", figure = figure)
        return graph, info
    else
        html_p("This shouldn't ever be displayed..."), ["Error!"]
    end
end


app.layout = dbc_container(
    [
        title
        html_br()
        packages_input
        html_br()
        drop_input
        html_br()
        html_br()
        dbc_spinner(tabs)
        checks
        html_br()
        html_br()
    ]
)

run_server(app, "0.0.0.0", debug = true)
