{***********************************************************************
*                              E X T P . P A S                         *
**--------------------------------------------------------------------**
*  D‚monstration de l'accŠs … la m‚moire ‚tendue par les fonctions     *
*  BIOS de l'interruption 15h, en g‚rant les disques virtuels          *
**--------------------------------------------------------------------**
*  Auteur           : MICHAEL TISCHER                                  *
*  d‚velopp‚ le     : 18.05.1989                                       *
*  DerniŠre m. … j. : 19.02.1992                                       *
***********************************************************************}

program ExtP;

uses Dos;

{-- Variables globales ------------------------------------------------}

var RdLen    : integer;                { Taille disques virtuels en Ko }
    ExtAvail : boolean;                  { M‚moire ‚tendue disponible? }
    ExtStart : longint;     { Adresse de la m‚moire ‚tendue : lin‚aire }
    ExtLen   : integer;                 { Taille m‚moire ‚tendue en Ko }

{***********************************************************************
*  ExtAdrConv : Convertit un pointeur en adresse lin‚aire de 32 bits   *
*               qui sera retourn‚e sous forme d'un LONGINT             *
**--------------------------------------------------------------------**
*  Entr‚e : Adr = Le pointeur … convertir                              *
*  Sortie : l'adresse convertie                                        *
***********************************************************************}

function ExtAdrConv ( Adr : pointer ) : longint;

type PTRREC = record                       { Sert … acc‚der aux compo- }
                 Ofs : word;                  { sants d'un pointeur au }
                 Seg : word;                                   { choix }
               end;

begin
  ExtAdrConv := longint( PTRREC( Adr ).seg ) shl 4 + PTRREC( Adr ).ofs;
end;

{***********************************************************************
*  ExtCopy : Copie des donn‚s entre deux tampons quelconque dans la    *
*            limite adressable de 16 Mo des 80286/i386/i486.           *
**--------------------------------------------------------------------**
*  Entr‚e : Start = Adresse du tampon Start sous forme d'adresse       *
*                   lin‚aire sur 32 bits.                              *
*            But  = Adresse du tampon But sous forme d'adresse         *
*                   lin‚aire sur 32 bits.                              *
*            Len   = Nombre d'octets … copier                          *
*  Info    : - Le nombre d'octets … copier doit ˆtre pair.             *
*            - L'usage de cette proc‚dure est r‚serv‚ … l'int‚rieur de *
*              cette Unit‚.                                            *
***********************************************************************}

procedure ExtCopy( Start, But : longint; Len : word );

{-- Structures de donn‚es pour l'accŠs … la m‚moire ‚tendue -----------}

type SDES = record                               { Descripteur segment }
              Longueur   : word;       { Longueur du segment en octets }
              AdrLo    : word;         { Bits 0 … 15 de l'adr. du segm }
              AdrHi    : byte;        { Bits 16 … 23 de l'adr. du segm }
              Attribut : byte;                   { Attribut du segment }
              Res      : word;                  { R‚serv‚ pour le i386 }
            end;

     GDT  = record                           { Global Descriptor Table }
              Dummy : SDES;
              GDTS  : SDES;
              Start : SDES;                             { copie de ... }
              But  : SDES;                                  { ... vers }
              Code  : SDES;
              Stack : SDES;
            end;

     LI = record                    { Sert … acc‚der aux ‚l‚ments d'un }
           LoWord : word;          { LongInts repr‚sentant une adresse }
           HiByte : byte;                       { lin‚aire sur 32 bits }
           dummy  : byte;
         end;

var GTab : GDT;                              { Global Descriptor Table }
    Regs : Registers;       { Registres process. pr appel interruption }
    Adr  : longint;                     { pour conversion de l'adresse }

begin
  FillChar( GTab, SizeOf( GTab ), 0 );           { Tous les champs … 0 }

   {-- Construction du descripteur du segment Start -------------------}

  GTab.Start.AdrLo      := LI( Start ).LoWord;
  GTab.Start.AdrHi      := LI( Start ).HiByte;
  GTab.Start.Attribut   := $92;
  GTab.Start.Longueur   := Len;

    {-- Construction du descripteur du segment But --------------------}

  GTab.But.AdrLo      := LI( But ).LoWord;
  GTab.But.AdrHi      := LI( But ).HiByte;
  GTab.But.Attribut   := $92;
  GTab.But.Longueur   := Len;

   {-- Copie de blocs de m‚moire … l'aide de la fonction $87 de   -----}
 {-- l'interruption $15 pour cassettes                            -----}

  Regs.AH := $87;                 { Nø de la fonction 'copier m‚moire' }
  Regs.ES := seg( GTab );                             { Adresse de GDT }
  Regs.SI := ofs( GTab );                                 { vers ES:SI }
  Regs.CX := Len shr 1;                { Nbre de mots … copier dans CX }
  intr( $15, Regs );                                { Appeler fonction }
  if ( Regs.AH <> 0 ) then                                   { Erreur? }
    begin                               { Oui, AH contient code Erreur }
      writeln('Erreur en accŠs … la m‚moire ‚tendue (', Regs.AH,')!');
      RunError;                { Quitter programme avec Run Time Error }
    end;
end;

{***********************************************************************
*  ExtRead : Copie un certain nombre d'octets de la m‚moire ‚tendue    *
*            dans la m‚moire principale.                               *
**--------------------------------------------------------------------**
*  Entr‚e :  ExtAdr = Adresse source (lin‚aire) dans m‚moire ‚tendue   *
*            BuPtr  = Pointeur sur le tampon cible dans m‚moire princ. *
*            Len    = Nombre d'octets … copier                         *
***********************************************************************}

procedure ExtRead( ExtAdr : longint;  BuPtr : pointer;  Len : word );

begin
  ExtCopy( ExtAdr, ExtAdrConv( BuPtr ), len );
end;

{***********************************************************************
*  ExtWrite : Copie un certain nombre d'octets de la m‚moire principale*
*             dans la m‚moire ‚tendue.                                 *
**--------------------------------------------------------------------**
*  Entr‚e :  BuPtr  = Ptr sur tampon source dans m‚moire principale    *
*            ExtAdr = Adresse But (lin‚aire) en m‚moire ‚tendue        *
*            Len    = Nombre d'octets … copier                         *
***********************************************************************}

procedure ExtWrite( BuPtr : pointer;  ExtAdr : longint;  Len : word );

begin
  ExtCopy( ExtAdrConv( BuPtr ), ExtAdr, len );
end;

{***********************************************************************
*  ExtGetInfo : Retourne l'adresse de la m‚moire ‚tendue et sa taille  *
*               en tenant compte des ‚ventuels disques virtuels de     *
*               type VDISK s'y trouvant                                *
**--------------------------------------------------------------------**
*  Entr‚e : aucune                                                     *
*  Sortie : aucune                                                     *
*  Globals : ExtAvail/W, ExtStart/W, ExtLen/W                          *
***********************************************************************}

procedure ExtGetInfo;

type NAME_TYP    = array [1..5] of char;
type BOOT_SECTEUR = record          { Secteur boot d'un disque virtuel }
                     dummy1   : array [1..3] of byte;
                     Name     : NAME_TYP;
                     dummy2   : array [1..3] of byte;
                     BpS      : word;
                     dummy3   : array [1..6] of byte;
                     Secteurs : word;
                     dummy4   : byte;    { remplissage pr taille paire }
                   end;

const VdiskName : NAME_TYP = 'VDISK';

var BootSek : BOOT_SECTEUR;             { copie le Boot Sector suppos‚ }
    Derniere  : boolean;                           { marque fin boucle }
    Regs    : Registers;    { Registres process. pr appel interruption }

begin
     {-- Demander la taille de la m‚moire ‚tendue et en d‚duire  ------}
     {-- la pr‚sence ‚ventuelle de m‚moire ‚tendue                  ---}

  Regs.ah := $88;  { nø de fonction: "renvoyer taille m‚moire ‚tendue" }
  intr( $15, Regs );                   { Appeler interruption Cassette }
  if ( Regs.AX = 0 ) then
    begin                                         { Pas de RAM ‚tendue }
      ExtAvail := FALSE;
      ExtLen   := 0;
      ExtStart := 0;
      exit;                                      { Retour … l'appelant }
    end;

  ExtAvail := TRUE;                       { M‚moire ‚tendue disponible }
  ExtLen   := Regs.AX;            { copier sa taille dans une variable }

{-- Rechercher disques virtuels type VDISK ----------------------------}

  ExtStart := $100000;                               { Si 1 Mo, lancer }
  Derniere := FALSE;                            { A partir du RAM disk }
  repeat                                        { boucle interrogation }
    ExtRead( ExtStart, @BootSek, SizeOf( BootSek ) );
    with BootSek do
      if Name = VDiskName then     { secteur boot d'un disque virtuel? }
        inc( ExtStart, longint( Secteurs ) * BpS ) {Oui, aprŠs RAM disk}
      else
        Derniere := TRUE;             { Pas d'autres RAM disks trouv‚s }
  until Derniere;

    {-- Soustraire la taille des disques virtuels ---------------------}
    {-- de la m‚moire ‚tendue disponible ------------------------------}

  dec( ExtLen, integer( (ExtStart - longint($100000)) shr 10) );
end;

{***********************************************************************
*  CheckExt : Teste la continuit‚ de la m‚moire ‚tendue libre          *
***********************************************************************}

procedure CheckExt;

var AdrTest   : longint;                        { Adresse du bloc test }
    i, j      : integer;                       { Compteur d'it‚rations }
    WriteBuf,                                          { Blocs de test }
    ReadBuf   : array [1..1024] of byte;
    Erreur    : boolean;                     { Pointeur Erreur m‚moire }

begin
  Randomize;                  { Initialise g‚n‚rateur nbres al‚atoires }
  AdrTest := ExtStart;
  for i := 1 to ExtLen do           { lit la m‚moire par blocs de 1 Ko }
    begin
      for j := 1 to 1024 do       { Remplir bloc avec nbres al‚atoires }
        WriteBuf[ j ] := Random( 255 );

      write(#13, AdrTest );    { Affiche adresse du bloc de 1 Ko test‚ }

                    {-- Lire tampon et le copier dans ReadBuf   -------}

      ExtWrite( @WriteBuf, AdrTest, 1024 );
      ExtRead( AdrTest, @ReadBuf, 1024 );

         {-- D‚finir identit‚ de WriteBuf et de ReadBuf  --------------}

      for j := 1 to 1024 do
        if WriteBuf[j] <> ReadBuf[j] then  { Contenu tampon identique? }
          begin                                         { Non, erreur! }
            writeln( '  Erreur! Adresse ',
                     AdrTest + longint(j-1) );
            Erreur := TRUE;
          end;

      inc( AdrTest, longint( 1024 ) );    { Positionner AdrTest sur le }
    end;                                         { bloc suivant d'1 Ko }
 writeln;
 if not( Erreur ) then                                      { Erreur ? }
   writeln( '€a baigne !' );                                     { Non }
end;

{***********************************************************************
*  P R O G R A M M E   P R I N C I P A L                               *
***********************************************************************}

begin
  writeln( #13#10'EXTDEMO - (c) 1989,92  by Michael Tischer'#13#10);
  ExtGetInfo;       { Donne disponibilit‚ et taille de m‚moire ‚tendue }
  if ExtAvail then                        { M‚moire ‚tendue es-tu l… ? }
    begin                                                        { Oui }
      RdLen := integer( (ExtStart - longint( $100000 ) ) shr 10 );
      if ( RdLen = 0 ) then                    { RAM disks install‚s ? }
        begin                                                    { Non }
          writeln( 'Aucun RAM disk install‚. ');
          writeln( 'La m‚moire ‚tendue libre commence … la ',
                   'limite du 1er Mo. ');
        end
      else                               { Oui, il y a des RAM disks ! }

begin
          writeln( 'Un ou plusieurs RAM disks occupent ',
                    RdLen,'Ko de m‚moire ‚tendue..');
          writeln( 'La m‚moire ‚tendue libre commence ', RdLen,
                   ' Ko aprŠs la limite du 1er Mo. ', RdLen, RdLen);
        end;
       writeln( ' Taille de la m‚moire ‚tendue libre ',
                 ExtLen, ' Ko.');
       writeln( #13#10'Test de la continuit‚ de la m‚moire ‚tendue',
                  ' en cours...'#13#10);
       CheckExt;
    end
  else
    writeln( 'Pas de m‚moire ‚tendue dans votre ordinateur !');
end.
