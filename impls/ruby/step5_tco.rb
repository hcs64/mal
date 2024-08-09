require_relative "mal_readline"
require_relative "types"
require_relative "reader"
require_relative "printer"
require_relative "env"
require_relative "core"

# read
def READ(str)
    return read_str(str)
end

# eval
def EVAL(ast, env)
    while true

    if env.get_or_nil(:"DEBUG-EVAL")
        puts "EVAL: #{_pr_str(ast, true)}"
    end

    case ast
    in Symbol
            return env.get(ast)
    in Vector
            return Vector.new ast.map{|a| EVAL(a, env)}
    in Hash
            new_hm = {}
            ast.each{|k,v| new_hm[k] = EVAL(v, env)}
            return new_hm

    # apply list

    in :def!, a1, a2
        return env.set(a1, EVAL(a2, env))
    in :"let*", a1, a2
        let_env = Env.new(env)
        a1.each_slice(2) do |a,e|
            let_env.set(a, EVAL(e, let_env))
        end
        env = let_env
        ast = a2 # Continue loop (TCO)
    in [:do, *]
        ast[1..-2].map{|a| EVAL(a, env)}
        ast = ast.last # Continue loop (TCO)
    in [:if, a1, a2, *]
        cond = EVAL(a1, env)
        if cond
            ast = a2 # Continue loop (TCO)
        else
            ast = ast[3] # Continue loop (TCO)
        end
    in :"fn*", a1, a2
        return Function.new(a2, env, a1) {|*args|
            EVAL(a2, Env.new(env, a1, List.new(args)))
        }
    in [a0, *]
        f = EVAL(a0, env)
        args = ast.drop(1)
        if f.class == Function
            ast = f.ast
            env = f.gen_env(List.new args.map{|a| EVAL(a, env)})
            # Continue loop (TCO)
        else
            return f[*args.map{|a| EVAL(a, env)}]
        end

    else                        # Empty list or scalar
      return ast
    end

    end
end

# print
def PRINT(exp)
    return _pr_str(exp, true)
end

# repl
repl_env = Env.new
RE = lambda {|str| EVAL(READ(str), repl_env) }
REP = lambda {|str| PRINT(EVAL(READ(str), repl_env)) }

# core.rb: defined using ruby
$core_ns.each do |k,v| repl_env.set(k,v) end

# core.mal: defined using the language itself
RE["(def! not (fn* (a) (if a false true)))"]

# repl loop
while line = _readline("user> ")
    begin
        puts REP[line]
    rescue Exception => e
        puts "Error: #{e}" 
        puts "\t#{e.backtrace[0..100].join("\n\t")}"
    end
end
