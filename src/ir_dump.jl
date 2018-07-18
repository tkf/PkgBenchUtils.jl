using JSON

function dump_ir(script, ir_funcs = (code_llvm,))
    @eval Main include($script)
    results = Dict()
    for f in ir_funcs
        results[Symbol(f)] = sub = Dict()
        for (key, args) in Main.IR_DUMP
            sub[key] = sprint(f, args...)
        end
    end
    return results
end

function _json_ir(script, ir_funcs)
    JSON.print(STDOUT, dump_ir(script, ir_funcs))
end

function assert_git_is_clean()
    status = readstring(`git status --short`)
    if strip(status) == ""
        return
    end
    error("""Git repository is not clean:
          $status""")
end

function _subproc_dump_ir(package_name, rev, script)
    ir_funcs = (code_llvm,)
    juliacmd = `julia -O3`
    return cd(Pkg.dir(package_name)) do
        assert_git_is_clean()
        current = strip(readstring(`git rev-parse $rev`))
        try
            run(`git checkout $rev`)
            code = """
            using PkgBenchUtils: _json_ir
            _json_ir($(repr(script)), $ir_funcs)
            """
            return open(JSON.parse, `$juliacmd -e $code`)
        finally
            run(`git checkout $current`)  # rollback
        end
    end
end

struct IRComparison
    package_name
    script
    target
    baseline
    target_results
    baseline_results
end

function compare_ir(script;
                    package_name = guess_package(),
                    target = "HEAD",
                    baseline = "HEAD^")
    return IRComparison(
        package_name,
        script,
        target,
        baseline,
        _subproc_dump_ir(package_name, target, script),
        _subproc_dump_ir(package_name, baseline, script),
    )
end
