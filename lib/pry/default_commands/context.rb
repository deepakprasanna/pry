require "pry/default_commands/ls"

class Pry
  module DefaultCommands

    Context = Pry::CommandSet.new do
      import Ls

      command "cd", "Start a Pry session on VAR (use `cd ..` to go back and `cd /` to return to Pry top-level)",  :keep_retval => true do |obj|
        case obj
        when nil
          output.puts "Must provide an object."
          next
        when ".."

          if _pry_.binding_stack.one?
            # when breaking out of top-level then behave like `quit` command
            _pry_.binding_stack.clear
            throw(:breakout)
          else
            # otherwise just pop a binding
            _pry_.binding_stack.pop.eval('self')
          end
        when "/"
          _pry_.binding_stack = [_pry_.binding_stack.first]
          nil
        when "::"
          _pry_.binding_stack.push TOPLEVEL_BINDING
          nil
        else
          _pry_.binding_stack.push Pry.binding_for(target.eval(arg_string))
          nil
        end
      end

      command "switch-to", "Start a new sub-session on a binding in the current stack (numbered by nesting)." do |selection|
        selection = selection.to_i

        if selection < 0 || selection > _pry_.binding_stack.size - 1
          output.puts "Invalid binding index #{selection} - use `nesting` command to view valid indices."
        else
          Pry.start(_pry_.binding_stack[selection])
        end
      end

      command "nesting", "Show nesting information." do
        output.puts "Nesting status:"
        output.puts "--"
        _pry_.binding_stack.each_with_index do |obj, level|
          if level == 0
            output.puts "#{level}. #{Pry.view_clip(obj.eval('self'))} (Pry top level)"
          else
            output.puts "#{level}. #{Pry.view_clip(obj.eval('self'))}"
          end
        end
      end

      command "jump-to", "Jump to a binding further up the stack, popping all bindings below." do |break_level|
        break_level = break_level.to_i
        nesting_level = _pry_.binding_stack.size - 1

        case break_level
        when nesting_level
          output.puts "Already at nesting level #{nesting_level}"
        when (0...nesting_level)
          _pry_.binding_stack.slice!(break_level + 1, _pry_.binding_stack.size)

        else
          max_nest_level = nesting_level - 1
          output.puts "Invalid nest level. Must be between 0 and #{max_nest_level}. Got #{break_level}."
        end
      end

      command "exit-all", "End the current Pry session (popping all bindings) and returning to caller. Accepts optional return value. Aliases: !!@" do
        # clear the binding stack
        _pry_.binding_stack.clear

        # break out of the repl loop
        throw(:breakout, target.eval(arg_string))
      end

      alias_command "!!@", "exit-all", ""

      command "exit", "Pop the current binding and return to the one immediately prior. Note this does NOT exit the program. Aliases: quit", :keep_retval => true do
        if _pry_.binding_stack.one?
          # when breaking out of top-level then behave like `exit-all`
          _pry_.binding_stack.clear
          throw(:breakout, target.eval(arg_string))
        else
          # otherwise just pop a binding
          popped_object = _pry_.binding_stack.pop.eval('self')

          # return a user-specified value if given
          if !arg_string.empty?
            target.eval(arg_string)
          else
            popped_object
          end
        end
      end

      alias_command "quit", "exit", ""

      command "exit-program", "End the current program. Aliases: quit-program, !!!" do
        Pry.save_history if Pry.config.history.should_save
        Kernel.exit
      end

      alias_command "quit-program", "exit-program", ""
      alias_command "!!!", "exit-program", ""

      command "!pry", "Start a Pry session on current self; this even works mid-expression." do
        target.pry
      end

      command "whereami", "Show the code context for the session. (whereami <n> shows <n> extra lines of code around the invocation line. Default: 5)" do |num|
        file = target.eval('__FILE__')
        line_num = target.eval('__LINE__')
        klass = target.eval('self.class')

        if num
          i_num = num.to_i
        else
          i_num = 5
        end

        meth_name = meth_name_from_binding(target)
        meth_name = "N/A" if !meth_name

        if file =~ /(\(.*\))|<.*>/ || file == "" || file == "-e"
          output.puts "Cannot find local context. Did you use `binding.pry` ?"
          next
        end

        set_file_and_dir_locals(file)
        output.puts "\n#{text.bold('From:')} #{file} @ line #{line_num} in #{klass}##{meth_name}:\n\n"

        # This method inspired by http://rubygems.org/gems/ir_b
        File.open(file).each_with_index do |line, index|
          line_n = index + 1
          next unless line_n > (line_num - i_num - 1)
          break if line_n > (line_num + i_num)
          if line_n == line_num
            code =" =>#{line_n.to_s.rjust(3)}: #{line.chomp}"
            if Pry.color
              code = CodeRay.scan(code, :ruby).term
            end
            output.puts code
            code
          else
            code = "#{line_n.to_s.rjust(6)}: #{line.chomp}"
            if Pry.color
              code = CodeRay.scan(code, :ruby).term
            end
            output.puts code
            code
          end
        end
      end

    end
  end
end
