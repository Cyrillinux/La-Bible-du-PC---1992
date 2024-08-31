{**********************************************************************}
{*                           C O N F I G                              *}
{*--------------------------------------------------------------------*}
{*    Fonction       : affiche sur l'‚cran la configuration du PC     *}
{*--------------------------------------------------------------------*}
{*    Auteur         : MICHAEL TISCHER                                *}
{*    D‚velopp‚ le   : 07/07/1987                                     *}
{*    DerniŠre modif.: 18/10/1992                                     *}
{**********************************************************************}

program CONFIG;

Uses Crt, Dos;                        { Int‚grer les unit‚s CRT et DOS }

{**********************************************************************}
{* PrintConfig: Affichage de la configuration d'un PC                 *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : Aucune                                                    *}
{* Infos  : la configuration est sortie en tenant compte du type de   *}
{*          PC                                                        *}
{**********************************************************************}

procedure PrintConfig;

var AT       : boolean;                          { Ce PC est-il un AT? }
    Regs : Registers;         { Registres processeur pour interruption }

begin
 ClrScr;                                               { Vider l'‚cran }
 if Mem[$F000:$FFFE] = $FC then AT := true      { Tester si AT ou bien }
                           else AT := false;               { PC ou  XT }
writeln('CONFIGP  -  (c) 1987, 1992 by Michael Tischer');
 writeln;
 writeln('Configuration de votre PC');
 writeln('----------------------------------------------------');
 write('Type de PC               : ');
 case Mem[$F000:$FFFE] of               { Lire … nouveau le type de PC }
  $FF : writeln('PC');                              { $FF, c'est un PC }
  $FE : writeln('XT');                              { $FE, c'est un XT }
else writeln('AT ou sup‚rieur')                     { $FC, c'est un AT }
 end;

 Intr($12, Regs);     { Lire taille m‚moire RAM avec interruption BIOS }
 writeln('M‚moire RAM              : ',Regs.ax,' Ko');
 if AT then                                     { Ce PC est-il un AT ? }
  begin                                                          { OUI }
   Regs.ah := $88;          { fonction pour lire taille m‚moire suppl. }
   Intr($15, Regs );           { Appeler interruption cassette du BIOS }

   writeln('RAM suppl‚mentaire       : ',Regs.ax,' Ko au dessus 1 Mo');
  end;
 Intr($11, Regs);      { Appeler interruption de configuration du BIOS }
 write('Mode vid‚o initial       : ');
 case Regs.al and 48 of                     { D‚terminer le mode vid‚o }
   0 : writeln('Ind‚fini');
  16 : writeln('40*25 caractŠres carte couleur');
  32 : writeln('80*25 caractŠres carte couleur');
  48 : writeln('80*25 caractŠres carte monochrome');
 end;
 writeln('Lecteurs de disquette    : ', succ(Regs.al shr 6 and 3));
 writeln('Interfaces s‚rie         : ', Regs.ah shr 1 and 3);
 writeln('Interfaces parallŠle     : ', Regs.ah shr 6)
end;

{**********************************************************************}
{*                         PROGRAMME PRINCIPAL                        *}
{**********************************************************************}

begin
 PrintConfig;                                   { Sortir configuration }
end.
