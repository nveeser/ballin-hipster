/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>
#include <string>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
 
 int comment_depth = 0;
 int integer_index = 0;
 int string_index = 0;

 std::string string_const;
  
%}

/*
 * Define names for regular expressions here.
 */

%x comment
%x line_comment
%x class
%x inherits
%x string
%x escape

COMMENT_START 	[(][*]
COMMENT_END	[*][)]

QUOTE           \"
STRING_CONST    [^\\\"]
ESCAPE          \\

WHITESPACE	[ \f\r\t\v]+
NEWLINE         \n

ID       	[a-zA-Z_][a-zA-Z0-9_]*

ASSIGN          <-
DARROW          =>
LE              <=

%%

--  {  BEGIN(line_comment); }

<line_comment>[^\n]*
<line_comment>[\n]       BEGIN(INITIAL); curr_lineno++;

 /*
  *  Nested comments
  */

{COMMENT_START}           BEGIN(comment); ++comment_depth; 
<comment>{COMMENT_START}  ++comment_depth; 
<comment>[^*(\n]*
<comment>"("[^*]          
<comment>"*"[)]           if (--comment_depth == 0) { BEGIN(INITIAL); }
<comment>"*"\n            curr_lineno++; 
<comment>"*"[^)\n]*
<comment>\n               curr_lineno++;

{COMMENT_END}	     {
  cool_yylval.error_msg = "Unmatched '*)'"; 
  return ERROR; 
}

<comment><<EOF>>     {
  cool_yylval.error_msg = "Comment extends beyond end of file";  
  BEGIN(INITIAL); 
  return ERROR;
}

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

t(?i:rue)       cool_yylval.boolean = true; return BOOL_CONST;
f(?i:alse)      cool_yylval.boolean = false; return BOOL_CONST;

(?i:class)	BEGIN(class); return CLASS;
(?i:inherits)	BEGIN(class); return INHERITS; 

(?i:if)		return IF; 
(?i:then)	return THEN; 
(?i:else)	return ELSE; 
(?i:fi)		return FI; 

(?i:while)	return WHILE; 
(?i:loop)	return LOOP; 
(?i:pool)	return POOL;
o
(?i:let)	return LET; 
(?i:in)	       	return IN;

(?i:case)	return CASE;
(?i:of)		return OF;
(?i:esac)	return ESAC;

(?i:not)        return NOT;
{ASSIGN}        return ASSIGN;
{DARROW}        return DARROW;
(?i:isvoid)     return ISVOID;
(?i:new)        return NEW;


[0-9]*          {
  yylval.symbol = new IntEntry(yytext, yyleng, integer_index++);
  return (INT_CONST); 
} 

 /* TypeId */
<class>{WHITESPACE}
<class>{ID}     {   
  cool_yylval.symbol = new StringEntry(yytext, yyleng, string_index++); 
  BEGIN(INITIAL); 
  return TYPEID; 
}

 /* ObjectId */
{ID}            {
  cool_yylval.symbol = new StringEntry(yytext, yyleng, string_index++); 
  return OBJECTID;
}

 /* Single char */
[+\-*/~<=(){};.,] return yytext[0];

{LE}            return LE;

:|@             BEGIN(class); return yytext[0];

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

{QUOTE}         BEGIN(string); string_const.clear();

<string>{STRING_CONST}  string_const.append(yytext, yyleng);

<string>{QUOTE} {
  cool_yylval.symbol = new StringEntry(string_const.data(), string_const.size(), string_index++); 
  BEGIN(INITIAL); 
  return STR_CONST;
}

<string>{ESCAPE} BEGIN(escape); 
<escape>n        string_const.append("\n"); BEGIN(string);
<escape>b        string_const.append("\b"); BEGIN(string);
<escape>t        string_const.append("\t"); BEGIN(string);
<escape>f        string_const.append("\f"); BEGIN(string);
<escape>[^nbtf]  string_const.append(yytext, 1); BEGIN(string);

 /*
  * Everything else.
  */

{WHITESPACE}     

{NEWLINE}        curr_lineno++;
.                cool_yylval.error_msg = "Parse Error"; return ERROR;

<<EOF>> { yyterminate(); }

%%
