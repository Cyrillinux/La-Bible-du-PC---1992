{**********************************************************************}
{*                             R T C P                                *}
{*--------------------------------------------------------------------*}
{*    Fonction       : fournit deux fonctions qui permettent d'‚crire *}
{*                     ou de lire des donn‚es sur l'horloge en temps  *}
{*                     r‚el                                           *}
{*--------------------------------------------------------------------*}
{*    Auteur         : MICHAEL TISCHER                                *}
{*    d‚velopp‚ le   : 10/07/1987                                     *}
{*    derniŠre modif.: 17/02/1992                                     *}
{**********************************************************************}

program RTCP;

Uses Crt;                                         { Int‚grer unit‚ CRT }

type Jours = array[1..7] of string[10];       { Tableau des noms jours }

const RTCAdrPort  = $70;                { Registre d'adresse de la RTC }
      RTCDtaPort  = $71;               { Registre de donn‚es de la RTC }

      SECONDES    = $00;  { Adresses de quelques cellules m‚moires RTC }
      MINUTES     = $02;
      HEURES      = $04;
      JOURSEMAINE = $06;
      JOUR        = $07;
      MOIS        = $08;
      ANNEE       = $09;
      ETATA       = $0A;
      ETATB       = $0B;
      ETATC       = $0C;
      ETATD       = $0D;
      DIAGNOSTIC  = $0E;
      SIECLE      = $32;

{**********************************************************************}
{* RTCRead : Lire le contenu d'un des cellules de m‚moire de la RTC   *}
{* Entr‚e  : Adresse de la cellule de m‚moire dans la RTC             *}
{* Sortie  : Contenu de cette cellule de m‚moire                      *}
{* Info    : si l'adresse sort du domaine autoris‚ (0 … 63), la       *}
{*           valeur -1 sera renvoy‚e                                  *}
{**********************************************************************}

function RTCRead(Adresse : integer) : integer;

begin
 if (Adresse < 0) or (Adresse > 63)               { Adresse correcte ? }
  then RTCRead := -1                                           { NON ! }
  else
   begin
    Port[RTCAdrPort] := Adresse;        { Transmettre adresse … la RTC }
    RTCRead := Port[RTCDtaPort]                     { Lire son contenu }
   end
end;

{**********************************************************************}
{* RTCDT: lit une des cellules de m‚moire de la date ou de l'heure de *}
{*        la RTC et convertit le r‚sultat en une valeur binaire si la *}
{*        RTC travaille en format BCD                                 *}
{* Entr‚e  : Adresse de la cellule de m‚moire dans la RTC             *}
{* Sortie  : Contenu de cette cellule de m‚moire comme valeur binaire *}
{* Info    : Si l'adresse est en dehors du domaine autoris‚ (0 - 63), *}
{*           la valeur -1 sera renvoy‚e                               *}
{**********************************************************************}

function RTCDT(Adresse : integer) : integer;

var Valeur : integer;                    { Pour stocker une valeur lue }

begin
 Valeur := RTCRead(Adresse);         { Lire contenu de cellule m‚moire }

 if( RTCRead(ETATB) and 4 = 4)                 { Mode BCD ou binaire ? }
  then
   RTCDT := Valeur                             { C'est le mode binaire }
  else                                             { C'est le mode BCD }
   RTCDT := (Valeur shr 4) * 10 + Valeur and 15; { Conv BCD en binaire }
end;

{**********************************************************************}
{* RTCWrite: Ecrire une valeur dans l'une des cellules de la RTC      *}
{* Entr‚e  : Voir plus bas                                            *}
{* Sortie  : aucune                                                   *}
{* Info    : Adresse doit ˆtre comprise entre 0 et 63                 *}
{**********************************************************************}

procedure RTCWrite(Adresse : integer;  { Adresse de cellule de m‚moire }
                   Contenu : byte);              { Son nouveau contenu }

begin
 Port[RTCAdrPort] := Adresse;           { Transmettre adresse … la RTC }
 Port[RTCDtaPort] := Contenu                  { Ecrire nouvelle valeur }
end;

{**********************************************************************}
{*                         PROGRAMME PRINCIPAL                        *}
{**********************************************************************}

begin

 ClrScr;                                               { Vider l'‚cran }
 writeln('RTC (c) 1987, 92 by Michael Tischer'#13#10);
 writeln('Informations tir‚es de l''horloge temps r‚el');
 writeln('==========================================='#13#10);

 if RTCRead(Diagnostic) and 128 = 0 then         { Piles en bon ‚tat ? }
  begin                                                          { Oui }
   writeln('- L''horloge est exploit‚e en mode ',
           (RTCRead(ETATB) and 2)*6+12,
           ' heures');
   writeln('- Il est : ', RTCDT(HEURES), ':', RTCDT(MINUTES):2,
           ':', RTCDT(SECONDES):2);
   write('- Nous sommes le : ');
   writeln(RTCDT(JOUR), '.', RTCDT(MOIS),
           '.',RTCDT(SIECLE), RTCDT(ANNEE));
  end
 else                                          { Piles de la RTC vides }
  write('       ATTENTION ! Les piles de l''horloge sont vides')
end.
