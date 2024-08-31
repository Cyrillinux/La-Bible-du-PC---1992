{***********************************************************************
*                           H M A P . P A S                            *
**--------------------------------------------------------------------**
*  Sujet        : D‚monstration d'accŠs direct au HMA sans             *
*                 l'assistance d'un pilote sp‚cial.                    *
**--------------------------------------------------------------------**
*  Auteur          : MICHAEL TISCHER                                   *
*  D‚velopp‚ le    : 27.07.1990                                        *
*  DerniŠre m. … j : 29.07.1990                                        *
***********************************************************************}

program HMAP;

uses Crt;                                                { pour ClrScr }

{***********************************************************************
* HMAAvail : D‚tecte la pr‚sence d'un processeur 80286 ou suivant et   *
*            la pr‚sence d'au moins 64 Ko de m‚moire ‚tendue           *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Sortie : TRUE si HMA disponible, sinon FALSE                         *
* Info    : - Cette fonction doit ˆtre appel‚e avant l'appel de toutes *
*             les autres proc‚dures et fonctions de ce programme.      *
***********************************************************************}

function HMAAvail : boolean;

begin
  inline (
          $33/$C0/                          { xor    ax,ax            *}
          $50/                              { push   ax               *}
          $9D/                              { popf                    *}
          $9C/                              { pushf                   *}
          $58/                              { pop    ax               *}
          $25/$00/$F0/                      { and    ax,0F000h        *}
          $3D/$00/$F0/                      { cmp    ax,0F000h        *}
          $74/$0E/                          { je     pashma  >ÄÄÄÄÄ¿  *}
          $B4/$88/                          { mov    ah,88h        ³  *}
          $CD/$15/                          { int    15h           ³  *}
          $3D/$40/$00/                      { cmp    ax,64         ³  *}
          $72/$05/                          { jb     pashma  >ÄÄÄÄÄ´  *}
          $B8/$01/$00/                      { mov    ax,0001h      ³  *}
          $EB/$02/                          { jmp    ende          ³  *}
          $33/$C0/                          { xor    ax,ax <ÄÄÄÄÄÄÄÙ  *}
          $88/$46/$FF                       { mov    [bp-1],al        *}
        );
end;

{***********************************************************************
* GateA20 : Bloque ou libŠre le canal d'adresses A20                   *
**--------------------------------------------------------------------**
* Entr‚e : libre = TRUE s'il faut lib‚rer le canal                     *
* Sortie : TRUE si l'accŠs au contr“leur de clavier r‚ussit, sinon     *
*          FALSE                                                       *
* Info    : - AprŠs l'appel de cette fonction, il est recommand‚ de    *
*             s'assurer … l'aide de la fonction IsA20On si le canal a  *
*             r‚ellement ‚t‚ lib‚r‚ car le proc‚d‚ utilis‚ ici ne      *
*             libŠre le canal que sur les machines ‚quip‚es du bus ISA *
***********************************************************************}

function GateA20( libre : boolean ) : boolean;

begin
  inline (
          $B4/$DD/                       { mov    ah,11011101b        *}
          $83/$7E/$04/$00/               { cmp    FREI,0              *}
          $74/$02/                       { je     g1 ÄÄÄÄÄÄÄÄÄÄÄ¿     *}
          $B4/$DF/                       { mov    ah,11011111b  ³     *}
          $33/$C9/                       { xor    cx,cx <ÄÄÄÄÄÄÄÙ     *}
          $FA/                           { cli                        *}
          $E4/$64/                       { in     al,64 <ÄÄÄÄÄÄÄ¿     *}
          $A8/$02/                       { test   al,02         ³     *}
          $E0/$FA/                       { loopnz ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ     *}
          $75/$1D/                       { jne    gerr ÄÄÄÄÄÄÄÄÄÄ>Ä¿  *}
          $B0/$D1/                       { mov    al,WO_COMMAND    ³  *}
          $E6/$64/                       { out    KB_COMMAND,al    ³  *}
          $E4/$64/                       { in     al,64 <ÄÄÄÄÄÄÄ¿  ³  *}
          $A8/$02/                       { test   al,02         ³  ³  *}
          $E0/$FA/                       { loopnz ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³  *}
          $75/$11/                       { jne    gerr ÄÄÄÄÄÄÄÄÄÄ>Ä´  *}
          $8A/$C4/                       { mov    al,ah            ³  *}
          $E6/$60/                       { out    KB_DATA,al       ³  *}
          $E4/$64/                       { in     al,64 <ÄÄÄÄÄÄÄ¿  ³  *}
          $A8/$02/                       { test   al,02         ³  ³  *}
          $E0/$FA/                       { loopnz ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ  ³  *}
          $75/$05/                       { jne    gerr ÄÄÄÄÄÄÄÄÄ>ÄÄ´  *}
          $B8/$01/$00/                   { mov    ax,0001h         ³  *}
          $EB/$02/                       { jmp    ende             ³  *}
          $33/$C0/                       { xor    ax,ax <ÄÄÄÄÄÄÄÄÄÄÙ  *}
          $FB/                           { sti                        *}
          $88/$46/$FF                    { mov    [bp-1],al           *}
         );
end;

{***********************************************************************
* IsA20On : Indique si le canal d'adresses A20 est lib‚r‚              *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
* Sortie : TRUE si le canal est libre, FALSE sinon                     *
***********************************************************************}

function IsA20On : boolean;

begin
  inline (
          $1E/                                { push   ds             *}
          $06/                                { push   es             *}
          $33/$F6/                            { xor    si,si          *}
          $8E/$DE/                            { mov    ds,si          *}
          $BF/$10/$00/                        { mov    di,0010        *}
          $B8/$FF/$FF/                        { mov    ax,FFFF        *}
          $8E/$C0/                            { mov    es,ax          *}
          $B9/$40/$00/                        { mov    cx,64          *}
          $FC/                                { cld                   *}
          $F3/$A7/                            { repe   cmpsw          *}
          $07/                                { pop    es             *}
          $1F/                                { pop    ds             *}
          $E3/$05/                            { jcxz   a20off ÄÄÄÄÄÄ¿ *}
          $B8/$01/$00/                        { mov    ax,0001h     ³ *}
          $EB/$02/                            { jmp    ende         ³ *}
          $33/$C0/                            { xor    ax,ax <ÄÄÄÄÄÄÙ *}
          $88/$46/$FF                         { mov    [bp-1],al      *}
        );
end;

{***********************************************************************
* HMATest : D‚monstration de l'accŠs au HMA                            *
**--------------------------------------------------------------------**
* Entr‚e : aucune                                                      *
***********************************************************************}

procedure HMATest;

type HMAR    = array [1..65520] of BYTE;              { le tableau HMA }
     HMARPTR = ^HMAR;                    { pointeur sur le tableau HMA }

var hmap  : HMARPTR;                                { pointeur sur HMA }
    i,                                         { Compteur d'it‚rations }
    err   : word;            { Nombre d'erreurs pendant l'accŠs au HMA }
    dummy : boolean;

begin
  if ( IsA20On ) then
   writeln( 'Le canal A20 est d‚j… lib‚r‚ !' )
  else
    if ( GateA20( TRUE ) = FALSE ) or ( IsA20On = FALSE ) then
      begin
        writeln( 'Attention! Le canal d''adresses A20 n''a pu ˆtre' +
                 'lib‚r‚.' );
        exit;
      end
    else
      writeln( 'L''accŠs … l''HMA vient d''ˆtre lib‚r‚.' );

  hmap := HMARPTR(Ptr( $FFFF, $0010 ));             { pointeur sur HMA }

  err := 0;                             { Aucune erreur jusqu'… pr‚sent}
  for i := 1 to 65520 do             { Teste chaque adresse s‚par‚ment }
    begin
      write( #13, 'Adresse: ', i );
      hmap^[i] := i mod 256;                   { Ecrire dans l'adresse }
      if ( hmap^[i] <> i mod 256 ) then                 { et la relire }
        begin                                                { Erreur! }
          writeln( ' ERREUR!' );
          inc( err );
        end;
    end;

  writeln( #13 );
  if ( err = 0 ) then                 { Evaluation du r‚sultat du test }
    writeln( 'HMA ok, aucune adresse incorrecte.')
  else
    writeln( 'ATTENTION! ', err, ' Des adresses incorrectes ont ‚t‚ ' +
             'd‚couvertes dans le HMA ! ');

  dummy := GateA20( FALSE );             { D‚sactiver canal d'adresses }
end;

{***********************************************************************
*                  P R O G R A M M E    P R I N C I P A L              *
***********************************************************************}

begin
 writeln( 'HMAP  -  Programme d‚mo HMA par MICHAEL TISCHER'#10 );
 if HMAAvail then
   begin
     HMATest;                                               { test HMA }
     writeln;
   end
 else
   writeln( 'Aucun accŠs possible … l''HMA.' );
end.
