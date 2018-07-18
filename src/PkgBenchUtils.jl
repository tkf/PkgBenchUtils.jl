module PkgBenchUtils

using PkgBenchmark: judge, export_markdown
using GitHub: create_gist

guess_package() = basename(pwd())

function _judge(package_name::String = guess_package();
                target = nothing,
                baseline = "HEAD^",
                kwargs...)

    if target === nothing
        args = (baseline,)
    else
        args = (target, baseline)
    end

    return judge(package_name, args...; kwargs...)
end

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
function post_results(results, script = nothing)
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
                    script = nothing,
                    public = false,
                    kwargs...)

    results = _judge(
        args...;
        script = script,
        kwargs...)

    posted_gist = post_results(results, script)
    run(`xdg-open $(get(posted_gist.html_url))`)

    return results, posted_gist
end

end # module
