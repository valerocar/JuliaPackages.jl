using Pkg
Pkg.activate(".")

#using Revise
using Dash, DashHtmlComponents, DashCoreComponents, DashBootstrapComponents
using Statistics, DataFrames, CSVFiles
using Dates
import TOML

include("utils.jl")

# App begins
df = load_dataframe()

app = dash(external_stylesheets = ["assets/style.css", dbc_themes.COSMO])

app.title = "Julia Packages Requests"

title = dbc_row(
    dbc_col(
        dbc_alert(
            color = "primary",
            html_center(
                html_div(
                    style = Dict("vertical-alight" => "middle"),
                    html_h1("Julia Packages requests"),
                ),
            ),
            className = "bmi-jumbotron",
        ),
    ),
    className = "mt-3",
)



ttip = dbc_tooltip("Enter a Julia package name and press the search button", target = "hola")

graph = dcc_graph(id = "graph", figure = plot_default())

graph_content = html_div([
    dbc_row([dbc_col(graph, width = 12)]),
    html_br(),
    dbc_row([dbc_col(html_div(id="info-content1",["Info1"]), width = 6), dbc_col(html_div(id="info-content2",["Info2"]), width = 6)]),
])

tabs = dbc_row([
    dbc_col(
        html_div([
            dbc_tabs(
                [
                    dbc_tab(label = "Users", tab_id = "user"),
                    dbc_tab(label = "CI runs", tab_id = "ci"),
                ],
                id = "tabs",
                active_tab = "user",
            ),
            html_div(id = "graph-content", graph_content),
        ]),
        width = 12,
    ),
],);


date_picker = dcc_datepickerrange(
    id = "dates",
    start_date = df."date"[begin],
    end_date = df."date"[end],
)

date_input = dbc_inputgroup([
    dbc_inputgrouptext(id = "date-range", "Date range"),
    date_picker,
    dbc_tooltip("Select a date range for the request's data", target = "date-range"),
])

search_input = dbc_inputgroup([
    dbc_inputgrouptext("Package", id = "package-label"),
    dbc_input(id = "search-input", placeholder = "name"),
    dbc_tooltip(
        "Enter a Julia package name and press the search button",
        target = "package-label",
    ),
    dbc_button("Search", color = "primary", id = "search-button"),
])


drop = dcc_dropdown(
    id = "drop",
    options = [(label = "PlotlyJS", value = "PlotlyJS")],
    style = Dict("width" => "300px"),
    multi = true,
    value = nothing,
)

drop2 = dcc_dropdown(
    id = "drop2",
    options = [(label = "Regular", value = "REG"), (label = "Cumulative", value = "CMT")],
    style = Dict("width" => "300px"),
    value = "REG",
)

mode2  = dbc_inputgroup([dbc_inputgrouptext("Mode", id = "mode2"), drop2, dbc_tooltip("Select plot type", target = "mode2")])

packages_input = dbc_row([
    dbc_col(search_input, width = 4),
    dbc_col(dbc_inputgroup([dbc_inputgrouptext("Select", id = "multi"), drop]), width = 8),
    dbc_tooltip(
        "Select one or more of the searched package(s) to render",
        target = "multi",
    ),
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
        Dict("label" => "Regression Line", "value" => "RL"),
        Dict("label" => "Seven days moving averages", "value" => "MA"),
    ],
    value = [],
    labelStyle = Dict("display" => "inline-block"),
)


function package_global_stats(name, stats)
    total_requests = stats["total"]
    interval = stats["interval"]
    precision = 2
    daily_average = round(total_requests/interval, digits = precision)
    α = stats["α"]
    β = stats["β"]
    dbc_card(
        [
            dbc_cardbody([
                html_h4("$(name) global statistics", className = "card-title"),
                html_div([
                    html_p("Total requests: $total_requests"),
                    html_p("Time interval: $interval days"),
                    html_p("Daily average: $daily_average"),
                    html_p("Regression slope: $β"),
                ],className = "card-text",)
                
            ]),
        ],
        style = Dict("width" => "12rem"),
    )
end 

function packages_info_table(packages, stats)
    table_header = [html_thead(html_tr([html_th("Package"), html_th("Daily average"), html_th("Regression slope")]))];
    rows = []
    for (i, name) in enumerate(packages)
        s = stats[i]
        total = s["total"]
        interval = s["interval"]
        precision = 2
        daily_average = round(total/interval, digits = precision)
        β = s["β"]
        row = html_tr([html_td(name), html_td("$daily_average"),html_td("$β")]);
        append!(rows, [row])
    end 

    table_body = [html_tbody(rows)];
    dbc_table([table_header; table_body], bordered = true);
end


callback!(
    app,
    Output("graph", "figure"),
    Output("info-content1", "children"),
    Output("info-content2", "children"),
    Input("tabs", "active_tab"),
    Input("drop", "value"),
    Input("dates", "start_date"),
    Input("dates", "end_date"),
    Input("checks", "value"),
    Input("drop2","value")
) do at, options, sd, ed, check_vals, drop2_val
    if typeof(options) === String
        options = [options]
    end
    figure, c_figure, stats_info =
        plot_graphs(options, check_vals, at, start_date = sd, end_date = ed)
    
    fout = figure
    if drop2_val == "CMT"
        fout = c_figure
    end
    info1 = [""]
    info2 = [""]
    if options !== nothing 
        if length(options) == 1
            info1 = [package_global_stats(options[1],stats_info[1])]
        else
            vals = [s["total"] for s in stats_info]
            figure = plot(pie(values = vals, labels = options, marker_colors = colors))
            info1 = [dcc_graph(figure = figure)]
            info2 = [packages_info_table(options, stats_info)]
        end
    end
    return fout, info1, info2
end

app.layout = dbc_container(
    [
        title
        html_br()
        packages_input
        html_br()
        dbc_row([dbc_col(checks,width=6),dbc_col(mode2,width=6)])
        html_br()
        drop_input
        html_br()
        html_br()
        dbc_spinner(tabs)
        html_br()
        html_br()
    ],
)

run_server(app, "0.0.0.0", debug = false)
