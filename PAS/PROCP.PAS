{**********************************************************************}
{*                            P R O C P                               *}
{*--------------------------------------------------------------------*}
{*    Fonction        : DÇtermine le type du processeur Çquipant      *}
{*                     un PC.                                         *}
{*--------------------------------------------------------------------*}
{*    Auteur          : MICHAEL TISCHER                               *}
{*    DÇveloppÇ le    : 16.08.1988                                    *}
{*    Derniäre modif. : 15.02.1992                                    *}
{**********************************************************************}

program PROCP;

{-- DÇclaration des routines Assembleur -------------------------------}

{$L procpa}                            { IntÇgrer le module Assembleur }

function GetProc : integer; external;
function GetCo   : integer; external;

{-- Types et variables globales ---------------------------------------}

type  NomsProc = string[20];          { Tableau des noms de processeur }

const NomProcr : array [0..8] of NomsProc =
                     ( 'Intel 8088',                          { Code 0 }
                       'Intel 8086',                          { Code 1 }
                       'NEC V20',                             { Code 2 }
                       'NEC V30',                             { Code 3 }
                       'Intel 80188',                         { Code 4 }
                       'Intel 80186',                         { Code 5 }
                       'Intel 80286',                         { Code 6 }
                       'i386',                                { Code 7 }
                       'i486' );                              { Code 8 }

      CoName : array [0..3] of NomsProc =
                 ( 'Pas de coprocesseur',                     { Code 0 }
                   '8087',                                    { Code 1 }
                   '80287',                                   { Code 2 }
                   'i387/i487' );                             { Code 3 }

{**********************************************************************}
{**                        PROGRAMME PRINCIPAL                       **}
{**********************************************************************}

begin
 
 writeln('€€€€€€€€€€€€ PROCP (c) 1988, 92 by Michael Tischer €€€');
 writeln;
 writeln('Processeur   : ', NomProcr[ GetProc ] );
 writeln('Coprocesseur : ', CoName[ GetCo ] );
 writeln;
end.
