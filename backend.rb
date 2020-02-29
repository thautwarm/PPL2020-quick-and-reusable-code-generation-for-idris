=begin
idris *.idr -o out.qb --codegen qb --cg-opt "--javaName" --cg-opt "--symemu"
requirements:
- Ruby 2.7
=end
require 'stringio'
require 'optparse'

def literal_map(kind, x)
    case kind
    when 'float'
        x.to_f
    when "int",  "bigint"
        x.to_i
    when "char", "string"
        x
    when "bool"
        x == "1" ? true : false
    when "unit"
        nil
    end
end


def code_list_to_string(prefix, io, xs)
    if xs.is_a? Array
        next_prefix = prefix + "  "
        xs.each {|x|
            io.write prefix
            code_list_to_string(next_prefix, io, x)
            io.write("\n")
        }
        return
    else
        raise xs unless xs.is_a? String
        io.write(xs)
    end
end

class Generate
    def ExternalCall(name, args)
        args = args.join(',')
        return "$__RTS.#{name}(#{args})"
    end

    def ExternalVar(name)
        return "$__RTS.#{name}"
    end

    def Var(name)
        return name
    end

    def Call(name, args)
        args = args.join(',')
        return "#{name}(#{args})"
    end

    def Defun(name, args, body)
        args = args.join(',')
        return ["def #{name}(#{args})", [].concat(*body), "end"]
    end

    def Introduction(n)
        return ["#{n} = nil"]
    end

    def Update(n, exp)
        raise "error" unless exp.is_a? String
        return ["#{n} = #{exp}"]
    end

    def Constant(n)
        return n.inspect
    end

    def Switch(var, xs, body)
        ret = []
        i = 0
        cs.each do |cc, stmts|
            head = i == 0 ? "if" : "elsif"
            ret.push "#{head} #{var} == #{cc}"
            raise "error" unless stmts.is_a? Array
            ret.push [].concat(*stmts)
        end
        ret.push "else"
        raise "error" unless body.is_a? Array
        ret.push [].concat(*body)
        ret.push("end")
        return ret
    end

    def If(cond, t, e)
        raise "error" unless cond.is_a? String
        raise "error" unless t.is_a? Array
        raise "error" unless e.is_a? Array
        return ["if #{cond}", [].concat(*t), "else", [].concat(*e), "end"]
    end

    def EffectExpr(exp)
        raise "error" unless exp.is_a? String
        return [exp]
    end

    def Return(exp)
        return ["return #{exp}"]
    end
end


def read_and_gen(io)
    generate = Generate::new
    ctor_stack = []
    obj_stack = []
    left_stack = []
    left = 1
    loop do
        while left > 0
            begin
                line = io.readline
            rescue EOFError
                return obj_stack.pop
            end
            pats = line.strip.split
            if pats.empty?
                next
            end
            dispatch = pats[0]
            left = left - 1
            case dispatch
            when "constructor"
                cons = pats[1]
                n = pats[2].to_i
                left_stack.push left
                left = n
                ctor_stack.push [(generate.method cons), n]
            when "literal"
                kind = pats[1]
                length = pats[2].to_i
                buf = io.read(length)
                io.readline
                obj_stack.push literal_map(kind, buf)

            when "list"
                n = pats[1].to_i
                left_stack.push left
                left = n
                ctor_stack.push [nil, n]
            else
                raise "malformed qb format"
            end
        end
        return obj_stack[0] if ctor_stack.empty?
        ctor, n = ctor_stack.pop
        args = []
        n.times {
           args.push obj_stack.pop
        }
        args.reverse!
        v = if ctor == nil
            args
        else
            ctor.(*args)
        end
        obj_stack.push v
        left = left_stack.pop
    end
end

=begin

=end
def main(filename, out)
    File.open(filename) do |file|
        code_secs = [].concat(*read_and_gen(file))
        if out.downcase == 'std'
            STDOUT.write("require_relative 'idris_rts'\n")
            STDOUT.write("$__RTS = IdrisRTS::new\n")
            code_list_to_string('', STDOUT, code_secs)
        else
            File.open(out, "w") do |wfile|
                wfile.write("require_relative 'idris_rts'\n")
                wfile.write("$__RTS = IdrisRTS::new\n")
                code_list_to_string('', wfile, code_secs)
            end
        end
    end
end


options = {}
OptionParser.new do |opts|
  opts.banner = "QB to Ruby Compiler"

  opts.on("f FILENAME", "--filename=FILENAME", "input filename") do |v|
    options[:filename] = v
  end
  opts.on("-o OUT", "--out=OUT", "output") do |v|
    options[:out] = v
  end
end.parse!

main(options[:filename], options[:out])
