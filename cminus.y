/* 
 * A BYACCJ `pecification for the Cminus language.
 * Author: Vijay Gehlot
 */
%{
import java.io.*;
import java.util.*;
%}
  
%token ID NUM
%token LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE
%token IF ELSE WHILE
%token VOID INT SEMI ASSIGN
%token MULT DIVIDE PLUS MINUS
%token LT GT LTE GTE EQ NOTEQ
%token PRINT INPUT RETURN COMMA
%token ERROR

%%

program:		{ 
                    symtab.enterScope();    // enter scope in symbol table
					// TODO generate code prologue
                } 
                declaration_list 
                {
                	if (usesRead) GenCode.genReadMethod();
                	// TODO generate class constructor code
                	// TODO generate epilog
                	symtab.exitScope();     // exit symbol table scope
                	if (!seenMain) semerror("No main in file"); 
				}
;

declaration_list:	  declaration_list declaration
                    | declaration
;

declaration:		  var_declaration
                    | fun_declaration
;

var_declaration:      type_specifier ID SEMI
                        {
                            int rettype = $1.ival;
                            String name = $2.sval;
                            
                            // check if it's already in there (double declaration, semantic error)
                            if(symtab.lookup(name)) {
                                semerror("re-declaration of " + name + " in current scope ");
                            // check for void type (semantic error)
                            } else if(rettype == VOID){
                                semerror("declaration of VOID variable " + name + " ");
                            // otherwise, put it in the symbol table
                            } else {
                                SymTabRec rec = new VarRec(name, symtab.getScope(), rettype);
                                symtab.insert(name,rec);
                            }
                        }
                    //| type_specifier assign_stmt    // allows declaration and assignment concurrently
                    | type_specifier ID LBRACKET NUM RBRACKET SEMI
                        {
                            int rettype = $1.ival;
                            String name = $2.sval;
                            int arraysize = $4.ival;
                            
                            // check if it's already in there (double declaration, semantic error)
                            if(symtab.lookup(name)) {
                                semerror("re-declaration of " + name + " in current scope ");
                                // check for void type (semantic error)
                            } else if(rettype == VOID){
                                semerror("declaration of VOID variable " + name + " ");
                                // otherwise, put it in the symbol table
                            } else {
                                SymTabRec rec = new ArrRec(name, symtab.getScope(), rettype, arraysize);
                                symtab.insert(name,rec);
                            }
                        }
;

//idlist:               ID COMMA idlist           // allows declaration of multiple vars in one line
//                    | assign_stmt
//                    | ID
//;

type_specifier:		  INT   { $$ = $1; }
                    | VOID  { $$ = $1; }
;

fun_declaration:      type_specifier ID
                        {
                            int rettype = $1.ival;
                            String name = $2.sval;
                            
                            // create FunRec for use in symbol table
                            FunRec rec = new FunRec(name, symtab.getScope(), rettype, null/*TODO get params*/);

                            // return FunRec to the rest of the grammar rule below
                            $$ = new ParserVal(rec);
                            
                            // check for function in symtab
                            if(symtab.lookup(name)) {
                                semerror("re-declaration of function " + name + " in current scope");
                            // main must be last fun_declaration
                            } else if(seenMain) {
                                semerror("function " + name + " declared after main");
                            // otherwise, add to symtab
                            } else {
                                symtab.insert(name,rec);
                                if(name.equals("main")) {
                                    seenMain = true;
                                }
                            }
                            symtab.enterScope();
                        }
                      LPAREN params RPAREN
                        {
                            FunRec rec = (FunRec)$3.obj;
                            List<SymTabRec> params = (List<SymTabRec>)$5.obj;
                            rec.setParams(params);
                        }
                      compound_stmt
                        {
                            firstTime = true;   // entered scope
                        }
;

params:			      param_list    { $$ = $1; }
                    | VOID
                    | /* empty */
;

param_list:	          param_list COMMA param
                        {
                            List<SymTabRec> reclist =(List<SymTabRec>)$1.obj;
                            SymTabRec rec = (SymTabRec)$3.obj;
                            reclist.add(rec);
                            $$ = new ParserVal(reclist);
                        }
                    | param
                        {
                            List<SymTabRec> reclist = new ArrayList<SymTabRec>();
                            SymTabRec rec = (SymTabRec)$1.obj;
                            reclist.add(rec);
                            $$ = new ParserVal(reclist);
                        }
;

param:	              type_specifier ID
                        {
                            int vartype = $1.ival;
                            String name = $2.sval;
                            
                            VarRec rec = new VarRec(name, symtab.getScope(), vartype);
                            $$ = new ParserVal(rec);
                            
                            // check symtab for dupe
                            if(symtab.lookup(name)) {
                                semerror("re-declaration of variable " + name + " in current scope");
                            } else {
                                symtab.insert(name,rec);
                            }
                        }
                    | type_specifier ID LBRACKET RBRACKET
                        {
                            int vartype = $1.ival;
                            String name = $2.sval;
                            
                            ArrRec rec = new ArrRec(name, symtab.getScope(), vartype, -1);
                            $$ = new ParserVal(rec);
                            
                            // check symtab for dupe
                            if(symtab.lookup(name)) {
                                semerror("re-declaration of variable " + name + " in current scope");
                            } else {
                                symtab.insert(name,rec);
                            }
                        }
;

compound_stmt:	      LBRACE
                        {
                            // special case (function braces)
                            if(firstTime) {
                                firstTime = false;
                            } else {
                                symtab.enterScope();
                            }
                        }
                      local_declarations statement_list RBRACE
                        {
                            symtab.exitScope();
                        }
;

local_declarations:	  local_declarations var_declaration
                    | /* empty */
;

statement_list:		  statement_list statement
                    | /* empty */
;

statement:	          assign_stmt
                    | compound_stmt
                    | selection_stmt
                    | iteration_stmt
                    | return_stmt
                    | print_stmt
                    | input_stmt
                    | call_stmt
                    | SEMI
;

call_stmt:            call SEMI
;

assign_stmt:          ID ASSIGN expression SEMI
                        {
                            String name = $1.sval;
                            if(symtab.get(name) == null) {
                                semerror("missing declaration of variable " + name);
                            }
                        }
                    | ID LBRACKET expression RBRACKET ASSIGN expression SEMI
                        {
                            String name = $1.sval;
                            if(symtab.get(name) == null) {
                                semerror("missing declaration of variable " + name);
                            }
                        }
;

selection_stmt:	      IF LPAREN expression RPAREN statement ELSE statement
;

iteration_stmt:	      WHILE LPAREN expression RPAREN statement
;

print_stmt:           PRINT LPAREN expression RPAREN SEMI
;

input_stmt:	          ID ASSIGN INPUT LPAREN RPAREN SEMI
                        {
                            String name = $1.sval;
                            if(symtab.get(name) == null) {
                                semerror("missing declaration of variable " + name);
                            }
                        }
;

return_stmt:	      RETURN SEMI
                    | RETURN expression SEMI
;

expression:	          additive_expression relop additive_expression
                    | additive_expression
;

relop:	              LTE
                    | LT
                    | GT
                    | GTE
                    | EQ
                    | NOTEQ
;

additive_expression:  additive_expression addop term
                    | term
;

addop:			      PLUS
                    | MINUS
;

term:	              term mulop factor
                    | factor
;

mulop:	              MULT
                    | DIVIDE
;

factor:	              LPAREN expression RPAREN
                    | ID
                        {
                            String name = $1.sval;
                            if(symtab.get(name) == null) {
                                semerror("missing declaration of variable " + name);
                            }
                        }
                    | ID LBRACKET expression RBRACKET
                        {
                            String name = $1.sval;
                            if(symtab.get(name) == null) {
                                semerror("missing declaration of variable " + name);
                            }
                        }
                    | call
                    | NUM
;

call:	              ID LPAREN args RPAREN
                        {
                            String name = $1.sval;
                            if(symtab.get(name) == null) {
                                semerror("missing declaration of function " + name + " in current scope");
                            }
                        }
;

args:	              arg_list
                    | /* empty */
;

arg_list:             arg_list COMMA expression
                    | expression
;

%%

/* reference to the lexer object */
private static Yylex lexer;

/* The symbol table */
public final SymTab<SymTabRec> symtab = new SymTab<SymTabRec>();

/* To check if main has been encountered and is the last declaration */
private boolean seenMain = false;

/* To take care of nuance associated with params and decls in compound stsmt */
private boolean firstTime = true;

/* To gen boilerplate code for read only if input was encountered  */
private boolean usesRead = false;

/* Interface to the lexer */
private int yylex()
{
    int retVal = -1;
    try
	{
		retVal = lexer.yylex();
    }
	catch (IOException e)
	{
		System.err.println("IO Error:" + e);
    }
    return retVal;
}
	
/* error reporting */
public void yyerror (String error)
{
    System.err.println("Parse Error : " + error + " at line " + 
		lexer.getLine() + " column " + 
		lexer.getCol() + ". Got: " + lexer.yytext());
}

/* For semantic errors */
public void semerror (String error)
{
    System.err.println("Semantic Error : " + error + " at line " + 
		lexer.getLine() + " column " + 
		lexer.getCol());
}

/* constructor taking in File Input */
public Parser (Reader r)
{
	lexer = new Yylex(r, this);
}

/* This is how to invoke the parser

public static void main (String [] args) throws IOException
{
	Parser yyparser = new Parser(new FileReader(args[0]));
	yyparser.yyparse();
}

*/
