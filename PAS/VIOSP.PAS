{**********************************************************************}
{*                              V I O S P                             *}
{*--------------------------------------------------------------------*}
{*    Fonction       : D‚termine le type des cartes vid‚o install‚es. *}
{*--------------------------------------------------------------------*}
{*    Auteur         : MICHAEL TISCHER                                *}
{*    D‚velopp‚ le   :  2/10/1988                                     *}
{*    DerniŠre MAJ   :  14/01/1991                                    *}
{**********************************************************************}

program VIOSP;

{$L viospa}                      { Int‚gration du module en assembleur }

      const NO_VIOS    = 0;                       { Pas de carte vid‚o }
      VGA        = 1;                                      { Carte VGA }
      EGA        = 2;                                      { Carte EGA }
      MDA        = 3;                     { Monochrome Display Adapter }
      HGC        = 4;                         { Hercules Graphics Card }
      CGA        = 5;                         { Color Graphics Adapter }

      NO_MON     = 0;                                { Pas de moniteur }
      MONO       = 1;                            { Moniteur monochrome }
      COLOR      = 2;                               { Moniteur couleur }
      EGA_HIRES  = 3;                      { Moniteur haute r‚solution }
      ANAL_MONO  = 4;                 { Moniteur analogique monochrome }
      ANAL_COLOR = 5;                    { Moniteur couleur analogique }

type Vios = record     { D‚crit la carte vid‚o et le moniteur connect‚ }
             Carte,
             Moniteur : byte;
            end;
     ViosPtr = ^Vios;                { Pointeur sur une structure VIOS }

procedure GetVios( vp : ViosPtr ) ; external ;

var VidSys : array[1..2] of Vios; { Tableau avec deux structures vid‚o }

{**********************************************************************}
{* PrintSys : Affiche diverses informations sur le systŠme vid‚o      *}
{* Entr‚e   : - CARTE : Num‚ro de code de la carte vid‚o              *}
{*            - MON   : Num‚ro de code du moniteur connect‚           *}
{* Sortie   : Aucune                                                  *}
{**********************************************************************}

procedure PrintSys( Carte, Mon : byte );

begin
  write(' Carte ');
  case Carte of
    VGA : write('VGA');
    EGA : write('EGA');
    MDA : write('MDA');
    CGA : write('CGA');
    HGC : write('HGC');
  end;
  write(' avec ');
  case Mon of
    MONO       : writeln('moniteur monochrome');
    COLOR      : writeln('moniteur couleur');
    EGA_HIRES  : writeln('moniteur haute r‚solution');
    ANAL_MONO  : writeln('moniteur analogique monochrome');
    ANAL_COLOR : writeln('moniteur analogique couleur');
  end;
end;

{**********************************************************************}
{**                       PROGRAMME PRINCIPAL                        **}
{**********************************************************************}

begin
  GetVios( @VidSys );          { D‚termine les cartes vid‚o install‚es }
  writeln('VIOS  -  (c) 1988 by MICHAEL TISCHER');
  write('SystŠme vid‚o primaire :  ');
  PrintSys( VidSys[1].Carte, VidSys[1].Moniteur );
  if VidSys[2].Carte <> NO_VIOS then        { Une autre carte  vid‚o ? }
    begin                                                        { OUI }
      write('SystŠme vid‚o secondaire :');
      PrintSys( VidSys[2].Carte, VidSys[2].Moniteur );
    end;
end.
