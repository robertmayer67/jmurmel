package com.robertmayer.lambda;

import java.io.InputStream;
import java.io.PrintStream;
import java.util.function.UnaryOperator;

public class Lambda {

    public static final int EOF = -1;
    public static final int SYMBOL_MAX = 32;
    public static final int DEVAL = 1, DPRIM = 2;

    public int debug = DPRIM;
    private InputStream in;
    private PrintStream out;

    private static class Pair {
        Object car;
        Pair cdr;

        Pair(String str, Pair cdr)               { this.car = str; this.cdr = cdr; }
        Pair(UnaryOperator<Pair> prim, Pair cdr) { this.car = prim; }
        Pair(Pair car, Pair cdr)                 { this.car = car; this.cdr = cdr; }
    }

    private Pair symbols = null;

    private int look;
    private int token[] = new int[SYMBOL_MAX];

    private boolean is_space(int x)  { return x == ' ' || x == '\t' || x == '\n' || x == '\r'; }
    private boolean is_parens(int x) { return x == '(' || x == ')'; }
    private int getchar() { try {return in.read(); } catch (Exception e) { throw new RuntimeException("I/O error reading"); } }
    private void gettoken() {
        int index = 0;
        while(is_space(look)) { look = getchar(); }
        if (is_parens(look)) {
            token[index++] = look;  look = getchar();
        } else {
            while(index < SYMBOL_MAX - 1 && look != EOF && !is_space(look) && !is_parens(look)) {
                if (index < SYMBOL_MAX - 1) token[index++] = look;
                look = getchar();
            }
        }
        token[index] = '\0';
    }

    private Pair e_true() { return cons( intern("quote"), cons( intern("t"), null)); }
    private Pair e_false() { return null; }

    private boolean is_atom(Object x) { return x instanceof String; }
    private boolean is_prim(Object x) { return x instanceof UnaryOperator<?>; }
    private boolean is_pair(Object x) { return x instanceof Pair; }
    private Object car(Pair x) { return x.car; }
    private Pair cdr(Pair x) { return x.cdr; }
    private Pair cons(String _car, Pair _cdr) { return new Pair(_car, _cdr); }
    private Pair cons(Pair _car, Pair _cdr) { return new Pair(_car, _cdr); }
    private Pair cons(UnaryOperator<Pair> _car, Pair _cdr) { return new Pair(_car, _cdr); }

    private Pair cons(Object _car, Pair _cdr) {
        if (is_atom(_car)) return new Pair((String)_car, _cdr);
        return new Pair((Pair)_car, _cdr);
    }

    private String tokenToString(int[] s) {
        StringBuffer ret = new StringBuffer(32);
        for (int c: s) {
            if (c == '\0') break;
            ret.append((char)c);
        }
        return ret.toString();
    }

    private String intern(int[] sym) {
        return intern(tokenToString(sym));
    }

    private String intern(String sym) {
        sym = sym.toUpperCase();
        Pair _pair = symbols;
        for ( ; _pair != null ; _pair = cdr(_pair)) {
            if (sym.equals(car(_pair))) {
                return (String) car(_pair);
            }
        }
        symbols = cons(sym, symbols);
        return (String) car(symbols);
    }

    private Object getobj() {
        if (token[0] == '(') return getlist();
        return intern(token);
    }

    private Object getlist() {
        gettoken();
        if (token[0] == ')') return null;
        Object tmp = getobj();
        if (is_atom(tmp)) return cons((String)tmp, (Pair) getlist());
        else return cons((Pair)tmp, (Pair) getlist());
    }

    private String print_obj(Object ob, boolean head_of_list) {
        if (is_pair(ob) ) {
            StringBuffer sb = new StringBuffer(200);
            if (head_of_list) sb.append('(');
            sb.append(print_obj(car((Pair) ob), true));
            if (cdr((Pair) ob) != null) {
                sb.append(' ').append(print_obj(cdr((Pair) ob), false));
            } else sb.append(')');
            return sb.toString();
        } else if (is_atom(ob)) {
            return ob.toString();
        } else if (is_prim(ob)) {
            return "<primitive>";
        } else if (ob == null) {
            return "null";
        } else {
            return "<unknown>";
        }
    }

    private Object eval(Object exp, Pair env) {
        if (debug >= DEVAL) {
            System.err.println();
            System.err.println("*** eval ***");
            System.err.print("env: "); System.err.println(print_obj(env, true));
            System.err.println();
            System.err.print("exp: "); System.err.println(print_obj(exp, true));
            System.err.println();
        }

        try {
        if (is_atom(exp) ) {
            for ( ; env != null; env = cdr(env) )
                if (exp == car((Pair) car(env)))
                    return car(cdr((Pair) car(env)));
            return null;

        } else if (is_atom( car ((Pair) exp))) { /* special forms */
            if (car((Pair) exp) == intern("quote")) {
                return car(cdr((Pair) exp));

            } else if (car((Pair) exp) == intern("if")) {
                if (eval (car(cdr((Pair) exp)), env) != null)
                    return eval (car(cdr(cdr((Pair) exp))), env);
                else
                    return eval (car(cdr(cdr(cdr((Pair) exp)))), env);

            } else if (car((Pair) exp) == intern("lambda")) {
                return exp; /* todo: create a closure and capture free vars */

            } else if (car((Pair) exp) == intern("apply")) { /* apply function to list */
                Pair args = evlist (cdr(cdr((Pair) exp)), env);
                args = (Pair)car(args); /* assumes one argument and that it is a list */
                return apply_primitive( (UnaryOperator<Pair>) eval(car(cdr((Pair) exp)), env), args);

            } else { /* function call */
                Object primop = eval (car((Pair) exp), env);
                if (is_pair(primop)) { /* user defined lambda, arg list eval happens in binding  below */
                    return eval( cons(primop, cdr((Pair) exp)), env );
                } else if (primop != null) { /* built-in primitive */
                    return apply_primitive((UnaryOperator<Pair>) primop, evlist(cdr((Pair) exp), env));
                }
            }

        } else if (car((Pair) car((Pair) exp)) == intern("lambda")) { /* should be a lambda, bind names into env and eval body */
            Pair extenv = env, names = (Pair) car(cdr((Pair) car((Pair) exp))), vars = cdr((Pair) exp);
            for (  ; names != null; names = cdr(names), vars = cdr(vars) )
                extenv = cons (cons((String) car(names),  cons(eval (car(vars), env), null)), extenv);
            return eval (car(cdr(cdr((Pair) car((Pair) exp)))), extenv);

        }
        out.println("cannot evaluate expression:" + print_obj(exp, true));
        return null;

        } catch (Exception e) {
            throw e; // convenient breakpoint
        }
    }

    private Pair evlist(Pair list, Pair env) {
        Pair head = null, insertPos = null;
        for ( ; list != null ; list = cdr(list) ) {
            Pair currentArg = cons(eval(car(list), env), null);
            if (head == null) {
                head = currentArg;
                insertPos = head;
            }
            else {
                insertPos.cdr = currentArg;
                insertPos = currentArg;
            }
        }
        return head;
    }

    private UnaryOperator<Pair> fcar =      (Pair a) -> {  return (Pair) car((Pair) car(a));  };
    private UnaryOperator<Pair> fcdr =      (Pair a) -> {  return cdr((Pair) car(a));  };
    private UnaryOperator<Pair> fcons =     (Pair a) -> {  return cons(car(a), (Pair)car(cdr(a)));  };
    private UnaryOperator<Pair> feq =       (Pair a) -> {  return car(a) == car(cdr(a)) ? e_true() : e_false();  };
    private UnaryOperator<Pair> fpair =     (Pair a) -> {  return is_pair(car(a))       ? e_true() : e_false();  };
    private UnaryOperator<Pair> fatom =     (Pair a) -> {  return is_atom(car(a))       ? e_true() : e_false();  };
    private UnaryOperator<Pair> fnull =     (Pair a) -> {  return car(a) == null        ? e_true() : e_false(); };
    private UnaryOperator<Pair> freadobj =  (Pair a) -> {  look = getchar(); gettoken(); return (Pair) getobj();  };
    private UnaryOperator<Pair> fwriteobj = (Pair a) -> {  out.print(print_obj(car(a), true)); out.println(""); return e_true();  };

    private Pair apply_primitive(UnaryOperator<Pair> primfn, Pair args) {
        if (debug >= DPRIM) System.err.println("(<primitive> " + print_obj(args, true) + ')');
        return primfn.apply(args);
    }

    public String interpret(InputStream in, PrintStream out) {
        this.in = in;
        this.out = out;
        Pair env = cons (cons(intern("car"),     cons(fcar, null)),
                   cons (cons(intern("cdr"),     cons(fcdr, null)),
                   cons (cons(intern("cons"),    cons(fcons, null)),
                   cons (cons(intern("eq?"),     cons(feq, null)),
                   cons (cons(intern("pair?"),   cons(fpair, null)),
                   cons (cons(intern("symbol?"), cons(fatom, null)),
                   cons (cons(intern("nil?"),    cons(fnull, null)),
                   cons (cons(intern("read"),    cons(freadobj, null)),
                   cons (cons(intern("write"),   cons(fwriteobj, null)),
                   cons (cons(intern("nil"),     cons((String)null,null)), null))))))))));
        look = getchar();
        gettoken();
        return print_obj( eval(getobj(), env), true );
    }

    public static void main(String argv[]) {
        Lambda interpreter = new Lambda();
        System.out.println(interpreter.interpret(System.in, System.out));
    }
}
