import util.newaa;
import std.algorithm;
import std.stdio;
import std.file;
import std.array;
import std.conv;
import core.thread;

static struct Tape {
    int pos;
    int[] tape = [0];

    int get() { return tape[pos]; }
    void inc() { tape[pos]++; }
    void dec() { tape[pos]--; }
    void advance() { pos++; if (tape.length <= pos) tape ~= 0; }
    void devance() { if (pos > 0) { pos--; } }
};
//
class Program {
    string code;

    NewAA!(int, int) bracket_map;
    //int[int] bracket_map;
    
    this(string text) {
        int[] leftstack;
        int pc = 0;
        
        for (int i = 0; i < text.length; i++) {
            char c = text[i];
            if (!canFind("[]<>+-,.", c)) continue;
            
            if (c == '[') leftstack ~= pc;
            else
            if (c == ']' && leftstack.length != 0) {
                int left = leftstack[leftstack.length - 1];
                leftstack.popBack();
                int right = pc;
                bracket_map[left] = right;
                bracket_map[right] = left;
            }
            
            pc++;
            code ~= c;
        }
    }
    
    void run() {
        auto tape = Tape();
        int pc = 0;

        while (pc < code.length) {
            switch (code[pc]) {
                case '+':
                    tape.inc();
                    break;
                case '-':
                    tape.dec();
                    break;
                case '>':
                    tape.advance();
                    break;
                case '<':
                    tape.devance();
                    break;
                case '[':
                    if (tape.get() == 0) { 
                        pc = bracket_map[pc];
                    }
                    break;
                case ']':
                    if (tape.get() != 0) {
                        pc = bracket_map[pc];
                    }
                    break;
                case '.':
                    write(tape.get().to!char);
                    stdout.flush();
                    break;
                default:
                    break;
            }
            ++pc;
        }
    }
};
//
//
//alias immA = immutable A;

int main(string[] args){
    import core.memory : GC;
    GC.disable;

    //    string text = readText(args[1]);
    //    auto p = new Program(text);
    //    p.run();

    NewAA!(int, string, 1048576) aa;
    //int[string] aa;
    long res;
    foreach (val; 0 .. 40_000_000) {
        string sv = val.to!string;
        aa[sv] = val + 1;
    }
    
    writeln(aa.length);
    //    
    //    //aa.rehash();
    //
    //    foreach (val; 0 .. 1_000_000) {
    //        res += aa[val.to!string];
    //    }
    //    
    //    writeln(res);
    //    
    return 0;
}

