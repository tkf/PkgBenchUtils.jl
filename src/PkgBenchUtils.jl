module PkgBenchUtils

using PkgBenchmark: judge, export_markdown
using GitHub: create_gist
using Setfield

struct Results
    results
    script
    posted

    Results(results, script = nothing, posted = nothing) =
        new(results, script, posted)
end

function Base.show(io::IO, r::Results)
    print(io, "PkgBenchUtils.Results")
    if r.script !== nothing
        print(io, " [", r.script, "]")
    end
    println(io)
    if r.posted !== nothing
        println(io, "URL: ", url(r))
    end
    show(io, r.results)
end

guess_package() = basename(pwd())

function _judge(package_name::String = guess_package();
                target = nothing,
                baseline = "HEAD^",
                script = nothing,
                kwargs...)

    if target === nothing
        args = (baseline,)
    else
        args = (target, baseline)
    end

    return Results(
        judge(package_name, args...;
              script = script,
              kwargs...),
        script,
    )
end

as_markdown(results::Results) = as_markdown(results.results)

function as_markdown(results)
    io = IOBuffer()
    export_markdown(io, results)
    seek(io, 0)
    return Markdown.parse(io)
end

function show_judge(args...; kwargs...)
    results = _judge(args...; kwargs...)
    display(as_markdown(results))
    println()
    return results
end

"""
https://juliaci.github.io/PkgBenchmark.jl/stable/export_markdown.html
"""
post_results(results::Results; kwargs...) =
    post_results(results.results, results.script; kwargs...)

function post_results(results, script;
                      public = false)
    package_name = results.baseline_results.name

    gist_json = Dict(
        :description => "A benchmark for $package_name",
        :public => public,
        :files => Dict(
            "benchmark.md" => Dict(
                :content => sprint(export_markdown, results),
            ),
        )
    )
    if script !== nothing
        gist_json[:files]["script.jl"] = Dict(
            :content => readstring(script),
        )
    end

    return create_gist(params = gist_json)
end

function post_judge(args...;
                    public = false,
                    open = true,
                    kwargs...)

    results = _judge(
        args...;
        kwargs...)

    results = @set results.posted = post_results(results; public=public)
    if open
        open_url(results)
    end

    return results
end

url(results) = get(results.posted.html_url)
open_url(results) = run(`xdg-open $(url(results))`)

end # module
