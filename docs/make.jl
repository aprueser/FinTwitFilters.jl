using FinTwitFilters
using Documenter

DocMeta.setdocmeta!(FinTwitFilters, :DocTestSetup, :(using FinTwitFilters); recursive=true)

makedocs(;
    modules=[FinTwitFilters],
    authors="Andrew Prueser <aprueser@gmail.com> and contributors",
    repo="https://github.com/aprueser/FinTwitFilters.jl/blob/{commit}{path}#{line}",
    sitename="FinTwitFilters.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aprueser.github.io/FinTwitFilters.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aprueser/FinTwitFilters.jl",
    devbranch="main",
)
