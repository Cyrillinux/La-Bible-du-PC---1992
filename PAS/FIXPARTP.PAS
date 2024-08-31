{**********************************************************************}
{*                      F I X P A R T P . P A S                       *}
{*--------------------------------------------------------------------*}
{*    Sujet          : Affiche les partitions d'un disque dur.        *}
{*--------------------------------------------------------------------*}
{*    Auteur         : MICHAEL TISCHER                                *}
{*    d‚velopp‚ le   : 26.04.1989                                     *}
{*   derniŠre m. … j.: 12.01.1992                                     *}
{*--------------------------------------------------------------------*}
{*    Appel          : FIXPARTP [ num‚ro de lecteur ]                 *}
{*                     Lecteur par d‚faut : lecteur 0 ("C")           *}
{**********************************************************************}

uses Dos;                                        { IntŠgre l'unit‚ DOS }

{== D‚clarations de types =============================================}

type  SecPos    = record              { donne la position d'un secteur }
                    Tete : byte;            { tˆte de lecture/‚criture }
                    SectCyl : word;     { nø de cylindre et de secteur }
                  end;

      PartEntry = record         { Entr‚e dans la table des partitions }
                    Status   : byte;                  { ‚tat partition }
                    StartSec : SecPos;               { premier secteur }
                    PartTyp  : byte;               { type de partition }
                    EndSec   : SecPos;               { dernier secteur }
                    SecOfs   : longint;       { Offset du boot secteur }
                    NbreSec  : longint;           { nombre de secteurs }
                  end;

      PartSec   = record              { d‚crit le secteur de partition }
                    BootCode  : array [0..$1BD] of byte;
                    PartTable : array [1..4] of PartEntry;
                    IdCode    : word;                          { $AA55 }
                  end;

{**********************************************************************}
{*  ReadPartSec : Copie un seceur de partition du disque dur dans un  *}
{*                tampon                                              *}
{**------------------------------------------------------------------**}
{*  Entr‚e : - Lecteur  : Code BIOS du lecteur ($80, $81 etc.)        *}
{*           - Tete     : Num‚ro de la tˆte de lecture/‚criture       *}
{*           - SecCyl   : nø de secteur et de cylindre au format BIOS *}
{*           - Tamp     : tampon dans lequel le secteur est charg‚    *}
{**********************************************************************}

function ReadPartSec( Lecteur, Tete : byte;
                      SecCyl        : word;
                      var Tamp      : PartSec ) : boolean;

var Regs : Registers;  { registres du processeur pour appel interrupt. }

begin
  Regs.AX := $0201;                 { nø de fonction "Read", 1 secteur }
  Regs.DL := Lecteur;                         { charger les autres     }
  Regs.DH := Tete;                            { paramŠtres dans les    }
  Regs.CX := SecCyl;                          { registres              }
  Regs.ES := seg( Tamp );
  Regs.BX := ofs( Tamp );
  Intr( $13, Regs);                    { appel interruption disque dur }
  ReadPartSec := ( Regs.Flags and 1 ) = 0;             { drapeau Carry }
end;                                                   { signale erreur}

{**********************************************************************}
{*  GetSectCyl: renvoie les nø de secteur et de cylindre aprŠs         }
{*              conversion des codes BIOS du secteur et du cylindre    }
{**------------------------------------------------------------------**}
{*  Entr‚e : SecCyl   : valeur … d‚coder                              *}
{*           Secteur  : r‚f‚rence … la variable Secteur               *}
{*           Cylindre : r‚f‚rence … la variable Cylindre              *}
{**********************************************************************}

procedure GetSectCyl( SecCyl : word; var Secteur, Cylindre : integer );

begin
  Secteur   := SecCyl and 63;                 { masque les bits 6 et 7 }
  Cylindre := hi( SecCyl ) + ( lo( SecCyl) and 192 ) shl 2;
end;

{**********************************************************************}
{*  ShowPartition: affiche les partitions du disque dur               *}
{**------------------------------------------------------------------**}
{*  Entr‚e : LC : nø de lecteur du disque dur demand‚ (0, 1, 2 etc )  *}
{**********************************************************************}

procedure ShowPartition( LC : byte );

var Tete     : byte;                   { tˆte de la partition courante }
    SectCyl  : byte;    { Secteur et cylindre de la partition courante }
    ParSec   : PartSec;              { le secteur de partition courant }
    Entry    : byte;                           { compteur d'it‚rations }
    Secteur,                              { stockent les nø de secteur }
    Cylindre : integer;                               { et de cylindre }
    Regs     : Registers; { registres processeur pour appel interrupt. }

begin
  writeln;
  LC := LC + $80;                    { pr‚pare nø lecteur pour le BIOS }
  if ReadPartSec( LC, 0, 1, ParSec ) then   { lit secteur de partition }
    begin                                { lecture correcte du secteur }
      Regs.AH := 8;                   { interroge identit‚ du lecteurs }
      Regs.DL := LC;
      Intr( $13, Regs);               { appel interruption duisque dur }
      GetSectCyl( Regs.CX, Secteur, Cylindre );
      writeln('ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ'+
              'ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»');
      writeln('º Lecteur ', LC-$80, ' : ', Regs.DH+1:2,
              ' tˆtes avec ', Cylindre:5, ' cylindres de',
              Secteur:3, ' secteurs                 º');
      writeln('º Table des partitions dans secteur de partition '+
              '                          º');
      writeln('ÌÍÍÑÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑ'+
              'ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍ¹');
      writeln('º  ³    ³                   ³     D‚but    ³'+
              '     Fin      ³Distance³       º');
      writeln('ºNø³Boot³Type               ³tˆte cyl. sec.³'+
              'Tˆte cyl. sec.³BootSec.³Nombre º');
      writeln('ÌÍÍØÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍÍÍÍÍÍÍØ'+
              'ÍÍÍÍÍÍÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍÍØÍÍÍÍÍÍÍ¹');
      for Entry:=1 to 4 do                { parcourt table des entr‚es }
        with ParSec.PartTable[ Entry ] do
          begin
          write('º ', Entry, '³');
          if Status = $80 then write ('Oui ')
                               else write ('Non ');
          write('³');
          case PartTyp of                  { ‚tablit type de partition }
            $00        : write('vide               ');
            $01        : write('DOS, FAT 12 bits   ');
            $02 or $03 : write('XENIX              ');
            $04        : write('DOS, FAT 16 bits   ');
            $05        : write('DOS, extended Part.');
            $06        : write('DOS 4.0 > 32 MB    ');
            $DB        : write('Concurrent DOS     ');
            else         write('inconnu (',PartTyp:3,')    ');
          end;
          GetSectCyl( StartSec.SectCyl, Secteur, Cylindre );
          write('³', StartSec.Tete:2,' ',Cylindre:5,'  ',Secteur:3 );
          GetSectCyl( EndSec.SectCyl, Secteur, Cylindre );
          write(' ³', EndSec.Tete:2,' ',Cylindre:5,'  ',Secteur:3 );
          writeln(' ³', SecOfs:8,'³', NbreSec:7,'º');
        end;
      writeln('ÈÍÍÏÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏ'+
              'ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍ¼'#13#10);
    end
  else
    writeln('Erreur en accŠs au secteur de boot ! ');
end;

{***********************************************************************
*              P R O G R A M M E    P R I N C I P A L                  *
***********************************************************************}

var Lecteur,                                 { variables de conversion }
    Erreur    : integer;                         { de l'argument pass‚ }

begin
  writeln( #13#10'ÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛ FIXPARTP - (c)',
           ' 1989, 92 by MICHAEL TISCHER ÛÛÛ' );
  Lecteur := 0;                            { 1er disque dur par d‚faut }
  if ParamCount = 1 then                     { autre lecteur demand‚ ? }
    begin                                                        { oui }
      val( ParamStr(1), Lecteur, Erreur );        { Ascii vers d‚cimal }
      if Erreur <> 0 then                     { erreur de conversion ? }
        begin                                                    { oui }
          writeln(#13#10'Num‚ro de lecteur invalide!');
          exit;                                    { quitter programme }
        end;
    end;
  ShowPartition( Lecteur );         { afficher le secteur de partition }
end.
