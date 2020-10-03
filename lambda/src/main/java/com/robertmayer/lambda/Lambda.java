package com.robertmayer.lambda;

import java.io.InputStream;
import java.io.PrintStream;
import java.util.Arrays;
import java.util.function.UnaryOperator;

public class Lambda {

    /// infrastructure
    public static final int EOF = -1;
    public static final int SYMBOL_MAX = 32;

    public static final int TRC_NONE = 0, TRC_LEX = 1, TRC_EVAL = 2, TRC_PRIM = 3;
    public int trace = TRC_NONE;

    private InputStream in;
    private PrintStream out;

    public static class Error extends RuntimeException {
        public static final long serialVersionUID = 1;
        Error(String msg) {
            super(msg, null, false, false);
        }
    }

    @FunctionalInterface
    public static interface Builtin {
        Pair apply(Pair x);
    }


    /// scanner
    private boolean escape;
    private int look;
    private int token[] = new int[SYMBOL_MAX];

    private boolean isSpace(int x)  { return !escape && (x == ' ' || x == '\t' || x == '\n' || x == '\r'); }
    private boolean isParens(int x) { return !escape && (x == '(' || x == ')'); }

    private int getchar() {
        try {
            escape = false;
            int c = in.read();
            if (c == '\\') {
                escape = true;
                return in.read();
            }
            if (c == ';') {
                while ((c = in.read()) != '\n' && c != EOF);
            }
            return c;
        } catch (Exception e) {
            throw new RuntimeException("I/O error reading");
        }
    }

    private void readToken() {
        int index = 0;
        while (isSpace(look)) { look = getchar(); }
        if (isParens(look)) {
            token[index++] = look;  look = getchar();
        } else {
            while (index < SYMBOL_MAX - 1 && look != EOF && !isSpace(look) && !isParens(look)) {
                if (index < SYMBOL_MAX - 1) token[index++] = look;
                look = getchar();
            }
        }
        if (index == 0) throw new Error("cannot read list. missing ')'?");
        token[index] = '\0';
        if (trace >= TRC_LEX)
            System.err.println("*** token |" + tokenToString(token) + '|');
    }

    private String tokenToString(int[] s) {
        StringBuffer ret = new StringBuffer(32);
        for (int c: s) {
            if (c == '\0') break;
            ret.append((char)c);
        }
        return ret.toString();
    }



    /// symbol table
    private Pair symbols = null;

    private String intern(int[] sym) {
        return intern(tokenToString(sym));
    }

    private String intern(String sym) {
        Pair pair = symbols;
        for ( ; pair != null; pair = (Pair)cdr(pair)) {
            if (sym.equalsIgnoreCase((String)car(pair))) {
                return (String) car(pair);
            }
        }
        symbols = cons(sym, symbols);
        return (String) car(symbols);
    }



    /// parser
    private Object readObj() {
        if (token[0] == '(') return readList();
        return intern(token);
    }

    private Object readList() {
        readToken();
        if (token[0] == ')') return null;
        Object tmp = readObj();
        if (isAtom(tmp)) return cons((String)tmp, (Pair) readList());
        else return cons((Pair)tmp, (Pair) readList());
    }



    /// eval - interpreter
    @SuppressWarnings("unchecked")
    private Object eval(Object exp, Pair env, int level) {
        dbgEvalStart(exp, env, level);
        try {
            if (isAtom(exp)) {
                if (exp == null) return null;
                Pair envEntry = assoc(exp, env);
                if (envEntry != null) return car((Pair)cdr(envEntry));
                throw new Error("'" + exp + "' is undefined");

            } else if (isAtom(car ((Pair) exp))) { /* special forms */
                if (car((Pair) exp) == intern("quote")) {
                    return car((Pair)cdr((Pair) exp));

                } else if (car((Pair) exp) == intern("if")) {
                    if (eval(car((Pair)cdr((Pair) exp)), env, level + 1) != null)
                        return eval(car((Pair)cdr((Pair)cdr((Pair) exp))), env, level + 1);
                    else
                        return eval(car((Pair)cdr((Pair)cdr((Pair)cdr((Pair) exp)))), env, level + 1);

                } else if (car((Pair) exp) == intern("lambda")) {
                    return exp;

                } else if (car((Pair) exp) == intern("labels")) { // labels bindings body -> object
                    Pair bindings = (Pair) car((Pair) cdr((Pair) exp));
                    Pair body =     (Pair) cdr((Pair) cdr((Pair) exp));
                    return evlabels(bindings, body, env, level);

                } else if (car((Pair) exp) == intern("cond")) {
                    return evcon((Pair) cdr((Pair) exp), env, level);

                } else if (car((Pair) exp) == intern("apply")) { /* apply function to list */
                    Pair args = evlis((Pair) cdr((Pair) cdr((Pair) exp)), env, level);
                    args = (Pair)car(args); /* assumes one argument and that it is a list */
                    return applyPrimitive((UnaryOperator<Pair>) eval(car((Pair)cdr((Pair) exp)), env, level + 1), args, level);

                } else { /* function call */
                    Object primop = eval(car((Pair) exp), env, level + 1);
                    if (isPair(primop)) { /* user defined lambda, arg list eval happens in binding  below */
                        return eval(cons(primop, cdr((Pair) exp)), env, level + 1);
                    } else if (primop != null) { /* built-in primitive */
                        return applyPrimitive((UnaryOperator<Pair>) primop, evlis((Pair) cdr((Pair) exp), env, level), level);
                    }
                }

            } else if (car((Pair) car((Pair) exp)) == intern("lambda")) { /* should be a lambda, bind names into env and eval body */
                Pair extenv = env, names = (Pair) car((Pair) cdr((Pair) car((Pair) exp))), vars = (Pair) cdr((Pair) exp);
                for ( ; names != null; names = (Pair) cdr(names), vars = (Pair) cdr(vars))
                    extenv = cons(cons((String) car(names),  cons(eval(car(vars), env, level + 1), null)), extenv);
                Pair body = (Pair) cdr((Pair) cdr((Pair) car((Pair) exp)));
                Object result = null;
                for (; body != null; body = (Pair) cdr(body))
                    result = eval(car(body), extenv, level);
                return result;

            }

            throw new Error("cannot eval expression '" + printObj(exp, true) + '\'');

        } catch (Exception e) {
            throw e; // convenient breakpoint for errors
        } finally {
            dbgEvalDone(level);
        }
    }

    /*
   (evcon (c e)
     (cond ((eval (caar c) e)
             (eval (cadar c) e))
           (t
             (evcon (cdr c) e))))
    */
    private Object evcon(Pair c, Pair e, int level) {
        for ( ; c != null; c = (Pair) cdr(c)) {
            Object condResult = eval(car((Pair) car(c)), e, level + 1);
            if (condResult != null) return eval(car((Pair) cdr((Pair) car(c))), e, level + 1);
        }
        return null;
    }

    private Pair evlis(Pair list, Pair env, int level) {
        Pair head = null, insertPos = null;
        for ( ; list != null; list = (Pair) cdr(list)) {
            Pair currentArg = cons(eval(car(list), env, level + 1), null);
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

    private Object evlabels(Pair bindings, Pair body, Pair env, int level) {
        Pair extenv = env;
        // TODO bindings verarbeiten und in extenv reinstecken

        Object result = null;
        for (; body != null; body = (Pair) cdr(body))
            result = eval(car(body), extenv, level);
        return result;
    }

    private void dbgEvalStart(Object exp, Pair env, int level) {
        if (trace >= TRC_EVAL) {
            char[] cpfx = new char[level*2]; Arrays.fill(cpfx, ' '); String pfx = new String(cpfx);
            System.err.println(pfx + "*** eval (" + level + ") ********");
            System.err.print(pfx + "env: "); System.err.println(printObj(env, true));
            System.err.print(pfx + "exp: "); System.err.println(printObj(exp, true));
        }
    }
    private void dbgEvalDone(int level) {
        if (trace >= TRC_EVAL) {
            char[] cpfx = new char[level*2]; Arrays.fill(cpfx, ' '); String pfx = new String(cpfx);
            System.err.println(pfx + "*** eval (" + level + ") done ***");
        }
    }



    /// data type used by interpreter program as well as interpreted programs
    private static class Pair {
        Object car, cdr;

        Pair(String str, Object cdr)               { this.car = str; this.cdr = cdr; }
        Pair(UnaryOperator<Pair> prim, Object cdr) { this.car = prim; }
        Pair(Pair car, Object cdr)                 { this.car = car; this.cdr = cdr; }
    }



    /// functions used by interpreter program, a subset is used by interpreted programs as well
    private boolean isAtom(Object x) { return x == null || x instanceof String; }
    private boolean isPrim(Object x) { return x instanceof UnaryOperator<?>; }
    private boolean isPair(Object x) { return x instanceof Pair; }
    private Object car(Pair x) { return x.car; }
    private Object cdr(Pair x) { return x.cdr; }
    private Pair cons(String car, Object cdr) { return new Pair(car, cdr); }
    private Pair cons(Pair car, Object cdr) { return new Pair(car, cdr); }
    private Pair cons(UnaryOperator<Pair> car, Object cdr) { return new Pair(car, cdr); }

    private Pair cons(Object car, Object cdr) {
        if (isAtom(car)) return new Pair((String)car, cdr);
        return new Pair((Pair)car, cdr);
    }

    private Pair assoc(Object atom, Pair env) {
        if (atom == null) return null;
        for ( ; env != null; env = (Pair)cdr(env))
            if (atom == car((Pair) car(env)))
                return (Pair) car(env);
        return null;
    }

    private Pair applyPrimitive(UnaryOperator<Pair> primfn, Pair args, int level) {
        if (trace >= TRC_PRIM) {
            char[] cpfx = new char[level*2]; Arrays.fill(cpfx, ' '); String pfx = new String(cpfx);
            System.err.println(pfx + "(<primitive> " + printObj(args, true) + ')');
        }
        return primfn.apply(args);
    }

    private String printObj(Object ob, boolean head_of_list) {
        if (ob == null) {
            return "nil";
        } else if (isPair(ob)) {
            StringBuffer sb = new StringBuffer(200);
            if (head_of_list) sb.append('(');
            sb.append(printObj(car((Pair) ob), true));
            if (cdr((Pair) ob) != null) {
                if (isPair(cdr((Pair) ob))) sb.append(' ').append(printObj(cdr((Pair) ob), false));
                else sb.append(" . ").append(printObj(cdr((Pair) ob), false)).append(')');
            } else sb.append(')');
            return sb.toString();
        } else if (isAtom(ob)) {
            return ob.toString();
        } else if (isPrim(ob)) {
            return "#<primitive>";
        } else {
            return "<internal error>";
        }
    }



    /// runtime for Lisp programs
    private Pair expTrue() { return cons(intern("quote"), cons(intern("t"), null)); }

    private UnaryOperator<Pair> fcar =      (Pair a) -> { return (Pair) car((Pair) car(a)); };
    private UnaryOperator<Pair> fcdr =      (Pair a) -> { return (Pair) cdr((Pair) car(a)); };
    private UnaryOperator<Pair> fcons =     (Pair a) -> { return cons(car(a), car((Pair) cdr(a))); };
    private UnaryOperator<Pair> fassoc =    (Pair a) -> { return assoc(car(a), (Pair) car((Pair) cdr(a))); };
    private UnaryOperator<Pair> feq =       (Pair a) -> { return car(a) == car((Pair) cdr(a)) ? expTrue() : null; };
    private UnaryOperator<Pair> fpair =     (Pair a) -> { return isPair(car(a))               ? expTrue() : null; };
    private UnaryOperator<Pair> fatom =     (Pair a) -> { return isAtom(car(a))               ? expTrue() : null; };
    private UnaryOperator<Pair> fnull =     (Pair a) -> { return car(a) == null               ? expTrue() : null; };
    private UnaryOperator<Pair> freadobj =  (Pair a) -> { look = getchar(); readToken(); return (Pair) readObj(); };
    private UnaryOperator<Pair> fwriteobj = (Pair a) -> { out.print(printObj(car(a), true)); return expTrue(); };

    private Pair environment() {
        return cons(cons(intern("car"),     cons(fcar, null)),
               cons(cons(intern("cdr"),     cons(fcdr, null)),
               cons(cons(intern("cons"),    cons(fcons, null)),
               cons(cons(intern("assoc"),   cons(fassoc, null)),
               cons(cons(intern("eq"),      cons(feq, null)),
               cons(cons(intern("pair?"),   cons(fpair, null)),
               cons(cons(intern("symbol?"), cons(fatom, null)),
               cons(cons(intern("null?"),   cons(fnull, null)),
               cons(cons(intern("read"),    cons(freadobj, null)),
               cons(cons(intern("write"),   cons(fwriteobj, null)),
               cons(cons(intern("nil"),     cons((String)null, null)),
               null)))))))))));
    }



    /// build environment, read an S-expression and invoke eval()
    public String interpret(InputStream in, PrintStream out) {
        this.in = in;
        this.out = out;
        Pair env = environment();
        look = getchar();
        readToken();
        return printObj(eval(readObj(), env, 0), true);
    }

    public static void main(String argv[]) {
        Lambda interpreter = new Lambda();
        System.out.println(interpreter.interpret(System.in, System.out));
    }
}
