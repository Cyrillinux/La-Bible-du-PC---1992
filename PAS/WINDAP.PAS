{**********************************************************************}
{*                        W I N D A P . P A S                         *}
{*--------------------------------------------------------------------*}
{*    Fonction       : Confirmer si Windows est actif et dans         *}
{*                    quel mode.                                      *}
{---------------------------------------------------------------------*}
{*    Auteur          : Michael Tischer                               *}
{*    D‚velopp‚ le    : 22.08.1991                                    *}
{*    DerniŠre modif. : 22.03.1992                                    *}
{**********************************************************************}

uses Dos;                                        { Ins‚rer l'unit‚ DOS }

const MULTIPLEX  = $2F;               { Nø de l'interruption Multiplex }
      NO_WIN     = $00;                            { Windows non actif }
      W_386_X    = $01;                   { Windows /386 V2.X en cours }
      W_REAL     = $81;              { Windows fonctionne en mode r‚el }
      W_STANDARD = $82;          { Windows fonctionne en mode standard }
      W_ENHANCED = $83;            { Windows fonctionne en mode ‚tendu }

{**********************************************************************}
{* WINDOWS : Confirme si Windows est actif                            *}
{* Entr‚e : HVERSION = Variable Integer devant contenir le num‚ro     *}
{*                     de version principal                           *}
{*          NVERSION = Integer devant contenir le num‚ro de version   *}
{*                     secondaire                                     *}
{* Sortie : Statut Windows, une constante parmi NO_WIN, W_386_X,      *}
{*          W_REAL, W_STANDARD ou W_ENHANCED                          *}
{* Infos    : Le num‚ro de version ne peut ˆtre obtenu que dans le    *}
{*            mode ‚tendu de Windows 3                                *}
{**********************************************************************}

function windows( var HVersion, NVersion : integer ) : integer;

var regs : registers;         {* Registre pour l'appel d'interruption *}
    Res  : integer;

{-- Cette fonction remplace l'appel de intr( $2F, Regs ) --------------}
{-- Regs.ax = $1600 (Test d'installation du mode ‚tendu), -------------}
{-- l'appel avec la fonction Pascal renvois des valeurs erron‚es    ---}

function int2fcall : integer;

begin
  inline( $b8 / $00 / $16 /             { mov   ax,1600h              *}
          $cd / $2f /                   { int   2Fh                   *}
          $89 / $46 / $FE );            { mov   [bp-2], ax            *}
  { A cet endroit, le compilateur rajoute "mov ax, [bp-2]" pour       *}
  { charger la variable de fonction locale dans le registre de retour *}
end;

begin
  HVersion := 0;                     { Initialise le num‚ro de version }
  NVersion := 0;

            {-- Identifie Windows x.y en mode ‚tendu ------------------}

  res := int2fcall;               { Test d'installation du mode ‚tendu }

  case ( lo(Res) ) of
    $01,
    $FF:  begin
            HVersion := 2;                        { Version principale }
            NVersion := 0;               { Version secondaire inconnue }
            Windows := W_386_X;
          end;
    $00,
    $80:  begin
            regs.ax := $4680;  { Identifier les modes R‚el et Standard }
            intr( MULTIPLEX, regs );
            if ( regs.al = $80 ) then
              Windows := NO_WIN            { Windows ne fonctionne pas }
            else
              begin
                   {-- Windows en mode R‚el ou Standard ---------------}

                regs.ax := $1605;   { Simule l'inst. d'un DOS-Extender }
                regs.bx := $0000;
                regs.si := $0000;
                regs.cx := $0000;
                regs.es := $0000;
                regs.ds := $0000;
                regs.dx := $0001;
                intr( MULTIPLEX, regs );
                if ( regs.cx = $0000 ) then
                  begin
                     {-- Windows en mode R‚el -------------------------}

                    regs.ax := $1606;
                    intr( MULTIPLEX, regs );
                    Windows := W_REAL;
                  end
                else
                  Windows := W_STANDARD;
              end;
          end;

   {-- Windows en mode Etendu, ax contient le num‚ro de version -------}

    else
      begin
        HVersion := lo(Res);          { Afficher la version de Windows }
        NVersion := hi(Res);
        Windows := W_ENHANCED;                { Windows en mode Etendu }
      end;
  end;
end;

{**********************************************************************}
{*                P R O G R A M M E   P R I N C I P A L               *}
{**********************************************************************}

var WindowsActif,                                    { Mode de Windows }
    HVer,                              { Version principale de Windows }
    NVer         : integer;            { Version secondaire de Windows }

begin
  writeln( 'ÛÛÛÛÛÛÛÛÛÛ WINDAP - (c) 1991, 92 by Michael Tischer ÛÛÛÛ' );
  writeln;
  WindowsActif := windows( HVer, NVer );
  case ( WindowsActif ) of
    NO_WIN    : writeln( 'Windows non actif ' );
    W_REAL    : writeln( 'Windows en mode R‚el' );
    W_STANDARD: writeln( 'Windows activ‚ en mode Standard' );
    W_386_X   : writeln( 'Windows/386 V 2.x actif' );
    W_ENHANCED: writeln( 'Windows V ', Hver, '.', NVer,
                         ' actif en mode Etendu' );
  end;
  halt( WindowsActif );
end.
