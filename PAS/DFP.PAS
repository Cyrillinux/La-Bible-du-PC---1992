{**********************************************************************}
{*                            D F P . P A S                           *}
{*--------------------------------------------------------------------*}
{*    SUJET       : Formate disquettes 3,5" et 5,25"                  *}
{*--------------------------------------------------------------------*}
{*    Auteur                : Michael Tischer                         *}
{*    D‚velopp‚ le          : 23.08.1991                              *}
{*    DerniŠre modification : 26.01.1992                              *}
{**********************************************************************}

program DFP;

Uses Dos;                              { IntŠgre les unit‚s Crt et DOS }

{-- Constantes --------------------------------------------------------}

const NO_DRIVE    = 0;                           { Lecteur introuvable }
      DD_525      = 1;                             { Lecteur: 5,25" DD }
      HD_525      = 2;                             { Lecteur: 5,25" HD }
      DD_35       = 3;                              { Lecteur: 3,5" DD }
      HD_35       = 4;                              { Lecteur: 3,5" HD }
      EssaisMax   = 5;                         { Nombre essais maximal }

{-- D‚clarations de types ---------------------------------------------}

type DdptType = array[ 0..10 ] of byte;          { Structure pour DDPT }
     DdptPtr = ^DdptType;                          { Pointeur sur DDPT }

     PhysDataType = record         { ParamŠtres physiques de formatage }
       Faces,                                { Nombre de faces demand‚ }
       Pistes,                                { Nombre Pistes par Face }
       Secteurs : byte;                    { Nombre Secteurs par Piste }
       DDPT     : DdptPtr; { Ptr sur table paramŠtres du lect. de disk.}
     end;

     LogDataType = record                { ParamŠtres de formatage DOS }
       Media,                                       { Octet de support }
       Cluster,                          { Nombre Secteurs par Cluster }
       FAT,                              { Nombre Secteurs pour la FAT }
       RootSize : byte;            { Entr‚es dans le r‚pertoire racine }
    end;

    PisteBufType = array[ 1..18, 1..512 ] of byte; { Tampon pour piste }

{-- Variables globales initialis‚es -----------------------------------}

const                      {-- Tables pr‚d‚finies pour chaque format --}


  {-- Donn‚es par d‚faut pour secteur BOOT avec programme chargement --}

      Masqueboot  : array[ 1..102 ] of byte =
                   ( $EB, $35,                { 0000   JMP 0037        }
                     $90,                     { 0002   NOP             }
                   {-- Donn‚es des BPB --------------------------------}

                     $50, $43, $49, $4E, $54, $45, $52, $4E,
                     $00, $00, $00, $01, $00, $00, $00, $00,
                     $00, $00, $00, $00, $00, $00, $00, $00,
                     $00, $00, $00, $00, $00, $00, $00, $00,
                     $00, $00, $00, $00, $00, $00, $00, $00,
                     $00, $00, $00, $00, $00, $00, $00, $00,
                     $00, $00, $00, $00,

                     {-- Programme de chargement ----------------------}

                     $FA,                     { 0037   CLI             }
                     $B8, $30, $00,           { 0038   MOV     AX,0030 }
                     $8E, $D0,                { 003B   MOV     SS,AX   }
                     $BC, $FC, $00,           { 003D   MOV     SP,00FC }
                     $FB,                     { 0040   STI             }
                     $0E,                     { 0041   PUSH    CS      }
                     $1F,                     { 0042   POP     DS      }
                     $BE, $66, $7C,           { 0043   MOV     SI,7C66 }
                     $B4, $0E,                { 0046   MOV     AH,0E   }
                     $FC,                     { 0048   CLD             }
                     $AC,                     { 0049   LODSB           }
                     $0A, $C0,                { 004A   OR      AL,AL   }
                     $74, $04,                { 004C   JZ      0052    }
                     $CD, $10,                { 004E   INT     10      }
                     $EB, $F7,                { 0050   JMP     0049    }
                     $B4, $01,                { 0052   MOV     AH,01   }
                     $CD, $16,                { 0054   INT     16      }
                     $74, $06,                { 0056   JZ      005E    }
                     $B4, $00,                { 0058   MOV     AH,00   }
                     $CD, $16,                { 005A   INT     16      }
                     $EB, $F4,                { 005C   JMP     0052    }
                     $B4, $00,                { 005E   MOV     AH,00   }
                     $CD, $16,                { 0060   INT     16      }
                     $33, $D2,                { 0062   XOR     DX,DX   }
                     $CD, $19 );              { 0064   INT     19      }

      BootMes : string =
       #13#10'DFP  -  (C) 1992 by Michael Tischer'+ #13#10 +
       #13#10'Disquette non systŠme ou d‚fectueuse!'#13#10 +
       'Veuillez changer de disquette et taper une touche' +
       #13#10;

{-- Variables globales non initialis‚es -------------------------------}

var AktDrive     : byte;           { Num‚ro du lecteur … formater 0, 1 }
    AktDriveType : byte;       { Type du lecteur de disquettes courant }
    PData        : PhysDataType; { Informations physiques de formatage }
    LData        : LogDataType;   { Informations logiques de formatage }
    AncDDPT      : pointer;                 { Pointeur sur ancien DDPT }
    OK           : boolean;      { Drapeau pour ex‚cution du programme }
    EndCode      : word;          { Valeur retourn‚e au process appel‚ }
    Param        : string;   { pour ‚valuation de la ligne de commande }

{**********************************************************************}
{* GetDriveType : REtourne le type d'un lecteur de disquettes         *}
{* Entr‚e       : DRIVE = Num‚ro de lecteur (0, 1 etc.)               *}
{* Sortie       : Code lecteur comme constante (DD_525, HD_525 etc.)  *}
{**********************************************************************}

function GetDriveType( Drive : byte ) : byte;

var Regs     : Registers;{ Registre processeur pour appel interruption }

begin
  Regs.ah := $08;             { Fonction: retourner le type de lecteur }
  Regs.dl := Drive;                                { Num‚ro de lecteur }
  intr( $13, Regs );                { Appel d'une interruption du BIOS }
  if ( Regs.flags and fcarry = 0 ) then   { Appel termin‚ sans erreur? }
    GetDriveType := Regs.bl                          { Type de lecteur }
  else
    GetDriveType := DD_525;           { Fonction $08 de l'interruption }
end;                            { introuvable  => type ordinateur = XT }

{**********************************************************************}
{* ResetDisk  : Reset disque sur tous les lecteurs                    *}
{* Entr‚e     : aucune                                                *}
{* Sortie     : aucune                                                *}
{* Info       : Le Reset est effectu‚ sur tous les lecteurs ind‚pen-  *}
{*              demment du num‚ro de lecteur charg‚ dans DL           *}
{**********************************************************************}

procedure DiskReset;

var Regs : Registers;    { Registre processeur pour appel interruption }

begin
  with Regs do
    begin
      ah := $00;          { Num‚ro de fonction pour appel interruption }
      dl := 0;                                { Lecteur a: (voir Info) }
    end;
  intr( $13, Regs );                              { appel interruption }
end;

{**********************************************************************}
{* GetFormatParamter: Retourne les paramŠtres physiques et logiques   *}
{*                    requis par le formatage                         *}
{* Entr‚e           : FORMSTRING = Capacit‚ demand‚e sous forme de    *}
{*                    chaŒne "360", "1200", "720", "1440"             *}
{*                    DRIVETYPE  = Code lecteur tel qu'il est         *}
{*                    retourn‚ par GetDriveType                       *}
{*                    PDATA      = Charg‚ avec les donn‚es de base du *}
{*                    format physique                                 *}
{*                    LDATA      = comme PDATA, mais donn‚es DOS      *}
{* Sortie           : TRUE si format possible sinon FALSE             *}
{* Info             : Vous pouvez ajouter de nouveaux formats en      *}
{*                    ‚tendant cette proc‚dure                        *}
{**********************************************************************}

function GetFormatParameter(     FormString : string;
                                 DriveType  : byte;
                             var PData      : PhysDataType;
                             var LData      : LogDataType  ) : boolean;

const DDPT_360  : DdptType = ( $DF, $02, $25, $02, $09, $2A,
                               $FF, $50, $F6, $0F, $08 );
      DDPT_1200 : DdptType = ( $DF, $02, $25, $02, $0F, $1B,
                               $FF, $54, $F6, $0F, $08 );
      DDPT_720  : DdptType = ( $DF, $02, $25, $02, $09, $2A,
                               $FF, $50, $F6, $0F, $08 );
      DDPT_1440 : DdptType = ( $DF, $02, $25, $02, $12, $1B,
                               $FF, $6C, $F6, $0F, $08 );

      LOG_360  : LogDataType = ( Media : $FD; Cluster  : 2;
                                 FAT   : 2;   RootSize : $70 );
      LOG_1200 : LogDataType = ( Media : $F9; Cluster  : 1;
                                 FAT   : 7;   RootSize : $E0 );
      LOG_720  : LogDataType = ( Media : $F9; Cluster  : 2;
                                 FAT   : 3;   RootSize : $70 );
      LOG_1440 : LogDataType = ( Media : $F0; Cluster  : 1;
                                 FAT   : 9;   RootSize : $E0 );

      PHYS_360  : PhysDataType = ( Faces   :  2; Pistes : 40;
                                   Secteurs :  9; DDPT   : @DDPT_360  );
      PHYS_1200 : PhysDataType = ( Faces   :  2; Pistes : 80;
                                   Secteurs : 15; DDPT   : @DDPT_1200 );
      PHYS_1440 : PhysDataType = ( Faces   :  2; Pistes : 80;
                                   Secteurs : 18; DDPT   : @DDPT_1440 );
      PHYS_720  : PhysDataType = ( Faces   :  2; Pistes : 80;
                                   Secteurs :  9; DDPT   : @DDPT_720  );

begin
  if ( FormString = '1200' ) then                 { 1,2 MB sur 5,25" ? }
    if ( DriveType = HD_525 ) then   { Lecteur et format compatibles ? }
      begin                               { Oui, renseigner paramŠtres }
        PData := PHYS_1200;
        LData := LOG_1200;
        GetFormatParameter := true;                  { Fin sans erreur }
      end
    else
      GetFormatParameter := false    { Lecteur et format incompatibles }
  else if ( FormString = '360' ) then                        { 360 Ko? }
    if ( DriveType = HD_525 ) or ( DriveType = DD_525 ) then
      begin     { Lecteur et format compatibles, renseigner paramŠtres }
        PData := PHYS_360;
        LData := LOG_360;
        GetFormatParameter := true;                  { Fin sans erreur }
      end
    else
      GetFormatParameter := false    { Lecteur et format incompatibles }
  else if ( FormString = '1440' ) then             { 1,44 MB auf 3,5"? }
    if ( DriveType = HD_35 ) then     { Lecteur et format compatibles? }
      begin                               { Oui, renseigner paramŠtres }
        PData := PHYS_1440;
        LData := LOG_1440;
        GetFormatParameter := true;                  { Fin sans erreur }
      end
    else
      GetFormatParameter := false    { Lecteur et format incompatibles }
  else if ( FormString = '720' ) then               { 720 Ko sur 3,5"? }
    if ( DriveType = HD_35 ) or ( DriveType = DD_35 ) then
      begin     { Lecteur et format compatibles, renseigner paramŠtres }
        PData := PHYS_720;
        LData := LOG_720;
        GetFormatParameter := true;                  { Fin sans erreur }
      end
    else
      GetFormatParameter := false    { Lecteur et format incompatibles }
  else
    GetFormatParameter := false;      { Le format demand‚ est invalide }
end;

{**********************************************************************}
{* DiskPrepare  : Pr‚parer le lecteur, param‚trer la vitesse de       *}
{*                transfert des donn‚es                               *}
{* Entr‚e       : DRIVE = Num‚ro de lecteur                           *}
{*                PDATA = ParamŠtres physiques                        *}
{* Sortie       : aucune                                              *}
{**********************************************************************}

procedure DiskPrepare( Drive : byte; PData : PhysDataType );

var Regs : Registers;    { Registre processeur pour appel interruption }

begin
  {-- D‚finir le type de support pour appeler formatage ---------------}

  with Regs do
    begin
      ah := $18;          { Num‚ro de fonction pour appel interruption }
      ch := PData.Pistes - 1;                 { Nombre Pistes par Face }
      cl := PData.Secteurs;                { Nombre Secteurs par Piste }
      dl := Drive;                                 { Num‚ro de lecteur }
    end;
  intr( $13, Regs );                              { appel interruption }
end;

{**********************************************************************}
{* FormatTrack  : Formate une piste                                   *}
{* Entr‚e       : voir ci-dessous                                     *}
{* Sortie       : ‚tat d'erreur                                       *}
{**********************************************************************}

function Formattrack( Lecteur,       { Num‚ro du lecteur de disquettes }
                      Face,                        { Num‚ro de la face }
                      Piste,                        { Piste … formater }
                      Nombre   : byte ) : byte;   { Secteurs par Piste }

type FormatTyp = record
                   DPiste, DFace, DCompteur, DLongueur : byte;
                 end;

var Regs      : Registers;{ Registre processeur pour appel interruption}
    Champdonn : array[ 1..18 ] of FormatTyp;     { maximal 18 Secteurs }
    Compteur   : byte;                         { Compteur d'it‚rations }
    essais  : byte;                            { Nombre essais maximal }

begin
  for Compteur := 1 to Nombre do
    with Champdonn[ Compteur ] do
      begin
        DPiste := Piste;                           { Num‚ro de la piste }
        DFace := Face;                           { Face de la disquette }
        DCompteur := Compteur;                      { Num‚ro du secteur }
        DLongueur := 2;               { Nombre octets par Secteur (512) }
      end;
  essais := EssaisMax;             { D‚finir le nombre d'essais maximal }
  repeat
    with Regs do
      begin
        ah := 5;          { Num‚ro de fonction pour appel interruption }
        al := Nombre;                   { Nombre de secteurs par piste }
        es := Seg( Champdonn );          { Adresse du Champ de donn‚es }
        bx := Ofs( Champdonn );             { dans les registres es:bx }
        dh := Face;                                { Num‚ro de la face }
        dl := Lecteur;                             { Num‚ro de lecteur }
        ch := Piste;                                 { Num‚ro de piste }
      end;
    intr( $13, Regs );              { Appel d'une interruption du BIOS }
    if ( Regs.flags and fcarry = 1 ) then                    { Erreur? }
      DiskReset;             { Oui, Reset disquette avant nouvel essai }
    dec( essais );
  until ( Regs.flags and fcarry = 0 ) or ( essais = 0 );
  Formattrack := Regs.ah;                           { Lire ‚tat erreur }
end;

{**********************************************************************}
{* VerifyTrack  : V‚rifier piste                                      *}
{* Entr‚e       : Lecteur, Face, Piste, nombre de secteurs            *}
{* Sortie       : Code erreur (0=OK)                                  *}
{**********************************************************************}

function VerifyTrack( Lecteur, Face, Piste, Secteurs : byte ) : byte;

var essais   : byte;                           { Nombre essais maximal }
    Regs     : Registers;{ Registre processeur pour appel interruption }
    TamponPiste : PisteBufType;               { M‚moire pour une piste }

begin
  essais := EssaisMax;            { D‚finir le Nombre d'essais maximal }
  repeat
    with Regs do
      begin
        ah := $04;        { Num‚ro de fonction pour appel interruption }
        al := Secteurs;                    { Nombre Secteurs par Piste }
        ch := Piste;                                 { Num‚ro de Piste }
        cl := 1;                          { Commencer par le secteur 1 }
        dl := Lecteur;                             { Num‚ro de lecteur }
        dh := Face;                                { Num‚ro de la face }
        es := Seg( TamponPiste );                  { Adresse du tampon }
        bx := Ofs( TamponPiste );
      end;
    intr( $13, Regs );                       { Appel interruption BIOS }
    if ( Regs.flags and fcarry = 1 ) then                    { Erreur? }
      DiskReset;             { Oui, reset disquette avant nouvel essai }
    dec( essais );
  until ( Regs.flags and fcarry = 0 ) or ( essais = 0 );
  VerifyTrack := Regs.ah;
end;

{**********************************************************************}
{* WriteTrack   : Ecrire piste                                        *}
{* Entr‚e       : Lecteur, Face, Piste, Secteur d‚but, Nombre, Donn‚es*}
{* Sortie       : Code erreur (0=OK)                                  *}
{**********************************************************************}

function WriteTrack(     Lecteur, Face, Piste,
                         Start, Nombre           : byte;
                     var Buffer ) : byte;

var essais : byte;                           { Nombre maximal d'essais }
    Regs     : Registers;{ Registre processeur pour appel interruption }

begin
  essais := EssaisMax;               { D‚finir nombre maximal d'essais }
  repeat
    with Regs do
      begin
        ah := $03;        { Num‚ro de fonction pour appel interruption }
        al := Nombre;                      { Nombre Secteurs par Piste }
        ch := Piste;                                 { Num‚ro de Piste }
        cl := Start;                      { Commencer par le secteur 1 }
        dl := Lecteur;                             { Num‚ro de lecteur }
        dh := Face;                                { Num‚ro de la face }
        es := Seg( Buffer );                     { Adresse pour tampon }
        bx := Ofs( Buffer );
      end;
    intr( $13, Regs );              { Appel d'une interruption du BIOS }
    if ( Regs.flags and fcarry = 1 ) then                    { Erreur? }
      DiskReset;             { Oui, reset disquette avant nouvel essai }
    dec( essais );
  until ( Regs.flags and fcarry = 0 ) or ( essais = 0 );
  WriteTrack := Regs.ah;
end;

{**********************************************************************}
{* PhysicalFormat : Formatage physique de la disquette (‚criture des  *}
{*                  pistes et secteurs)                               *}
{* Entr‚e         : DRIVE  = Code lecteurs                            *}
{*                  PDATA  = ParamŠtres physiques                     *}
{*                  VERIFY = TRUE pour demander v‚rification          *}
{* Sortie         : FALSE si erreur, sinon TRUE                       *}
{**********************************************************************}

function PhysicalFormat( Drive  : byte;
                         PData  : PhysDataType;
                         Verify : boolean ) : boolean;

var essais : byte;                           { Nombre d'essais maximal }
    Regs     : Registers;{ Registre processeur pour appel interruption }
    Piste,                                            { Piste courante }
    Face,                                              { Face courante }
    Status   : byte;         { VAleur de retour des fonctions appel‚es }


begin
  {-- Formatage de la disquette piste par piste ------------------------------}

  for Piste := 0 to PData.Pistes - 1 do     { Ecrire toutes les pistes }
    for Face := 0 to PData.Faces - 1 do      { Ecrire toutes les faces }
      begin
        Write( #13'Piste: ', Piste : 2, '  Face: ', Face : 2 );
       {-- 5 essais au maximum pour formater une piste ----------------}

        essais := EssaisMax;         { D‚finir nombre maximal d'essais }
        repeat
          Status := FormatTrack( Drive, Face, Piste, PData.Secteurs );
          if ( Status = 3 ) then  { Disquette prot‚g‚e en l'‚criture ? }
            begin
              PhysicalFormat := false;   { Quitter proc‚dure si erreur }
              WriteLn( #13'Disquette prot‚g‚e contre l''‚criture' );
              exit;                            { Terminer la proc‚dure }
            end;
          if ( Status = 0 ) and Verify then
            Status := VerifyTrack( Drive, Face, Piste, PData.Secteurs );
          dec( essais );
          if ( Status > 0 ) then               { Le formatage a ‚chou‚ }
            DiskReset;
        until ( Status = 0 ) or ( essais = 0 );
        if ( Status > 0 )  then          { Erreur pendant le formatage }
          begin
            PhysicalFormat := false;     { Quitter proc‚dure si erreur }
            WriteLn( #13'Piste Erreur?aft      ' );
            exit;                              { Terminer la proc‚dure }
          end;
      end;
  PhysicalFormat := true;              { Proc‚dure quitt‚e sans erreur }
end;

{**********************************************************************}
{* LogicalFormat : Formatage logique de la disquette (‚criture du     *}
{*                 secteur de boot, des FAT et du r‚pertoire racine)  *}
{* Entr‚e        : DRIVE = Num‚ro de lecteur                          *}
{*                 PDATA = informations physiques de formatage        *}
{*                 LDATA = informntions logiques de formatage         *}
{* Sortie        : TRUE si aucune erreur ne s'est produite            *}
{**********************************************************************}

function LogicalFormat( Drive : byte;
                        PData : PhysDataType;
                        LData : LogDataType ) : boolean;

var Status         : byte;             { Retour de la fonction appel‚e }
    TousSecteurs   : word;                  { Nombre total de secteurs }
    i              : byte;                     { Compteur d'it‚rations }
    AktSector,
    AktSide,
    AktTrack       : byte;
    Nombre         : integer;   { Nombre des secteurs restant … ‚crire }
    TamponPiste    : PisteBufType;            { M‚moire pour une piste }

begin
  fillchar( TamponPiste, word( PData.Secteurs ) * 512, 0 );{Vide tampon}

  {-- Secteur de boot : partie fixe -----------------------------------}

  move( Masqueboot, TamponPiste, 102 );   { Copier masque secteur boot }
  move( BootMes[1], TamponPiste[ 1, 103 ],      { Copie textes de boot }
        ord(BootMes[0]) );
  TamponPiste[ 1, 511 ] := $55;      { Signe de fin du secteur de boot }
  TamponPiste[ 1, 512 ] := $AA;

  {-- Secteur de boot : partie variable  ------------------------------}

  TousSecteurs := PData.Pistes * PData.Secteurs * Pdata.Faces;
  TamponPiste[ 1, 14 ] := LData.Cluster;            { Longueur Cluster }
  TamponPiste[ 1, 18 ] := LData.RootSize; { Nombre Entr‚es ds r‚p.rac. }
  TamponPiste[ 1, 20 ] := lo( TousSecteurs );{ Nombre total de secteur }
  TamponPiste[ 1, 21 ] := hi( TousSecteurs );       { sur la disquette }
  TamponPiste[ 1, 22 ] := LData.Media;           { descripteur support }
  TamponPiste[ 1, 23 ] := LData.FAT;                { Longueur des FAT }
  TamponPiste[ 1, 25 ] := PData.Secteurs;         { Secteurs par piste }
  TamponPiste[ 1, 27 ] := PData.Faces;               { Nombre de faces }

  {-- Cr‚er FAT et sa copie (contient 00) -----------------------------}

  TamponPiste[ 2, 1 ] := LData.Media;                 { Cr‚er 1Šre FAT }
  TamponPiste[ 2, 2 ] := $FF;
  TamponPiste[ 2, 3 ] := $FF;
  TamponPiste[ LData.FAT + 2, 1 ] := LData.Media;     { Cr‚er 2Šme FAT }
  TamponPiste[ LData.FAT + 2, 2 ] := $FF;
  TamponPiste[ LData.FAT + 2, 3 ] := $FF;

  {-- Boot-Sektor und FAT schreiben -----------------------------------}

  Status := WriteTrack( Drive, 0, 0, 1, PData.Secteurs, TamponPiste );
  if Status <> 0 then
    LogicalFormat := FALSE

  {-- Pas d'erreur? Ecrire r‚pertoire racine --------------------------}

  else
    begin
      fillchar( TamponPiste, 512, 0 );                  { Secteur vide }
      AktSector := PData.Secteurs;      { Ecriture 1Šre piste complŠte }
      AktTrack := 0;                                  { Piste courante }
      AktSide := 0;                                    { Face courante }

      {-- Retourner nombre des secteurs restants et les ‚crire --------}

      Nombre := LData.FAT * 2 + ( LData.Rootsize * 32 div 512 ) +
                1 - PData.Secteurs;

      i := 1;
      repeat
        inc( AktSector );                            { Secteur suivant }
        if ( AktSector > PData.Secteurs ) then      { Fin de la piste? }
          begin
            AktSector := 1;                  { Continuer par secteur 1 }
            inc( AktSide );                          { Face suivante ? }
            if ( AktSide = PData.Faces ) then       { D‚j… 2Šme face ? }
              begin
                AktSide := 0;                   { Revenons … la face 0 }
                inc( AktTrack );
              end;
          end;
        Status := WriteTrack( Drive, AktSide, AktTrack,
                              AktSector, 1, TamponPiste );
        inc( i );
      until ( i > Nombre ) or ( status <> 0 );
      LogicalFormat := ( status = 0 )
    end;
end;

{**********************************************************************}
{*                   PROGRAMM  PRINCIPAL                              *}
{**********************************************************************}

begin
  WriteLn( 'DFP  -  (c) 1992 by Michael Tischer'#13#10 );
  if paramcount > 1 then                          { Donn‚ paramŠtres ? }
    begin                                               { Oui, ‚valuer }
      Param := paramstr( 1 );   { REtourner lecteur ( 0 = a:, 1 = b: ) }
      AktDrive := ord( upcase( Param[ 1 ] ) ) - 65;
      AktDriveType := GetDriveType( AktDrive ); { Type lecteur courant }
      if ( AktDriveType > 0 ) then                 { Lecteur existant? }
        begin                       { Oui, le programme peut continuer }
          if GetFormatParameter( paramstr( 2 ), AktDriveType,
                                 PData, LData) then
            begin                 { Format et lecteur sont compatibles }
              DiskPrepare( AktDrive, PData );
              GetIntVec( $1E, AncDDPT );            { Stocker anc DDPT }
              SetIntVec( $1E, PData.DDPT );    { D‚finir nouvelle DDPT }

              Param := paramstr( 3 );
              ok := PhysicalFormat( AktDrive, PData,
                                    upcase( Param[ 1 ] ) <> 'N' );
              if ok then
                begin
                  Writeln(#13'Ecriture du secteur de boot et des FAT ');
                  ok := LogicalFormat( AktDrive, PData, LData )
                end;

                       {-- Evaluation du formatage --------------------}

              if ok then
                begin
                  WriteLn( #13'Formatage o.k.                 ' );
                  EndCode := 0;
                end
              else
                begin
                  WriteLn( #13'Une erreur a interrompu le formatage' );
                  EndCode := 1;
                end;
              SetIntVec( $1E, AncDDPT );          { Restaurer anc DDPT }
            end
          else
            begin
              WriteLn( 'Le format demand‚ ne peut ˆtre ' +
                       'utilis‚ sur ce lecteur!' );
              EndCode := 2;   { Valeur de retour au processus appelant }
            end
        end
      else
        begin
          WriteLn( 'Le lecteur de disquettes demand‚ n''existe pas');
          EndCode := 3;       { Valeur de retour au processus appelant }
        end
    end
  else
    begin
      writeln( 'Appel: DFP Lecteur   Format   [ NV ]' );
      writeln( '            ³          ³          ³' );
      writeln( '            ³          ³          ³' );
      writeln( '   A: ou B: ³          ³          ³' );
      writeln( '                       ³          ³' );
      writeln( '  360, 720, 1200, 1440 ³          ³' );
      writeln( '                                  ³' );
      writeln( '                  NV = pas Verify ³' );
      EndCode := 4;          { Valeur de retour au processus appelant }
    end;
  Halt( EndCode );
end.
