{**********************************************************************}
{*                              E M M P                               *}
{*--------------------------------------------------------------------*}
{*    Fonction       : Fournit diff‚rentes fonctions permettant       *}
{*                     d'acc‚der … la m‚moire EMS ou … l'EMM.         *}
{*--------------------------------------------------------------------*}
{*    Auteur         : MICHAEL TISCHER                                *}
{*    D‚velopp‚ le   : 30/08/1988                                     *}
{*    DerniŠre modif.: 30/03/1992                                     *}
{**********************************************************************}

program EMMP;

Uses Dos, CRT;                        { Int‚grer les unit‚s DOS et CRT }

type  ByteBuf = array[0..1000] of byte;      { zone m‚moire comme Byte }
      CharBuf = array[0..1000] of char;      { zone m‚moire comme Char }
      BytePtr = ^ByteBuf;              { Pointeur sur une zone d'octet }
      CharPtr = ^CharBuf;                 { Pointeur sur une zone Char }

const EMS_INT   = $67;        { Nø d'interruption pour l'accŠs … l'EMM }
      EMS_ERR   = -1;                    { Est renvoy‚ en cas d'erreur }
      W_EMS_ERR = $FFFF;                { Code d'erreur en format WORD }
      EmmName   : array[0..7] of char = 'EMMXXXX0';     { Nom de l'EMM }

var   EmmEC,                  { Ici sont plac‚s les codes d'erreur EMM }
      i        : byte;                            { Compteur de boucle }
      Handle,                   { Handle pour l'accŠs … la m‚moire EMS }
      EmmVer   : integer;                 { Num‚ro de version de l'EMM }
      NmbPage,                                   { Nombre de pages EMS }
      PageSeg  : word;              { Adresse de segment du Page Frame }
      Touche    : char;


{**********************************************************************}
{* EmsInst: D‚termine si m‚moire EMS et un EMM correspondant          *}
{*          install‚s.                                                *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : TRUE si m‚moire EMS pr‚sente, sinon FALSE.                *}
{**********************************************************************}

function EmsInst : boolean;

type  EmmName  = array[1..8] of char;              { Nom du driver EMS }
      EmmNaPtr = ^EmmName;                       { Pointeur sur le nom }

const Name : EmmName = 'EMMXXXX0';             { D‚signation du driver }

var Regs : Registers;   { Registres processeur pour appel interruption }

begin
        {*-- Mettre en place ptr sur nom dans en-tˆte driver de p‚riph.}

  Regs.ax := $35 shl 8 + EMS_INT; { Nø fct.: Rech. vec. interrupt. $67 }
  MsDos( Regs );                        { Appeler interruption DOS $21 }

  EmsInst := (EmmNaPtr(Ptr(Regs.ES,10))^ = Name);
                                                  { TRUE si nom trouv‚ }
end;

{**********************************************************************}
{* EmsNumPage: D‚termine le nombre total de pages EMS.                *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : EMS_ERR en cas d'erreur, sinon nombre de pages EMS.       *}
{**********************************************************************}

function EmsNumPage : integer;

var Regs : Registers;   { Registres processeur pour appel interruption }

begin
  Regs.ah := $42;                { Nø fct.: D‚terminer nombre de pages }
  Intr(EMS_INT, Regs);                                   { Appeler EMM }
  if( Regs.ah <>0 ) then               { Une erreur est-elle apparue ? }
    begin                                                        { Oui }
      EmmEC := Regs.ah;                      { Ranger le code d'erreur }
      EmsNumPage := EMS_ERR;                       { Afficher l'erreur }
    end
  else                                                  { Pas d'erreur }
    EmsNumPage := Regs.dx;         { Renvoyer le nombre total de pages }
end;

{**********************************************************************}
{* EmsFreePage: D‚termine le nombre de pages EMS encore libres.       *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : EMS_ERR en cas d'erreur, sinon nombre de pages EMS        *}
{*          non encore r‚serv‚es.                                     *}
{**********************************************************************}

function EmsFreePage : integer;

var Regs : Registers;   { Registres processeur pour appel interruption }

begin
  Regs.ah := $42;                { Nø fct.: D‚terminer nombre de pages }
  Intr(EMS_INT, Regs);                                   { Appeler EMM }
  if (Regs.ah <>0 ) then               { Une erreur est-elle apparue ? }
    begin                                                        { Oui }
      EmmEC := Regs.ah;                      { Ranger le code d'erreur }
      EmsFreePage := EMS_ERR;                      { Afficher l'erreur }
    end
  else                                                  { Pas d'erreur }
    EmsFreePage := Regs.bx;       { Renvoyer le nombre de pages libres }
end;

{**********************************************************************}
{* EmsFrameSeg: D‚termine l'adresse de segment du Page Frame.         *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : EMS_ERR en cas d'erreur, sinon adr. seg. obtenue          *}
{**********************************************************************}

function EmsFrameSeg : word;

var Regs : Registers;   { Registres processeur pour appel interruption }

begin
  Regs.ah := $41;            { Nø fct.: Rech adr segment de Page Frame }
  Intr(EMS_INT, Regs);                                   { Appeler EMM }
  if (Regs.ah <>0 ) then               { Une erreur est-elle apparue ? }
    begin                                                        { Oui }
      EmmEC := Regs.ah;                      { Ranger le code d'erreur }
      EmsFrameSeg := W_EMS_ERR;                    { Afficher l'erreur }
    end
  else                                                  { Pas d'erreur }
    EmsFrameSeg := Regs.bx;   { Renvoyer adresse segment de Page Frame }
end;

{**********************************************************************}
{* EmsAlloc: Alloue le nombre de pages sp‚cifi‚ et renvoie un handle  *}
{*           pour l'accŠs … ces pages.                                *}
{* Entr‚e : PAGES: nombre de pages … allouer.                         *}
{* Sortie : EMS_ERR en cas d'erreur, sinon le handle.                 *}
{**********************************************************************}

function EmsAlloc( Pages : integer ) : integer;

var Regs : Registers;   { Registres processeur pour appel interruption }

begin
  Regs.ah := $43;                             { Nø fct.: Allouer pages }
  Regs.bx := Pages;                  { Fixer nombre de pages … allouer }
  Intr(EMS_INT, Regs);                                   { Appeler EMM }
  if (Regs.ah <>0 ) then               { Une erreur est-elle apparue ? }
    begin                                                        { Oui }
      EmmEC := Regs.ah;                      { Ranger le code d'erreur }
      EmsAlloc := EMS_ERR;                         { Afficher l'erreur }
    end
  else                                                  { Pas d'erreur }
    EmsAlloc := Regs.dx;                             { Renvoyer handle }
end;

{**********************************************************************}
{* EmsMap  : Calque une des pages logiques allou‚es sous le handle    *}
{*           transmis sur la page physique du Page Frame.             *}
{* Entr‚e : HANDLE: Le Handle fourni par EmsAlloc.                    *}
{*          LOGP  : La page logique … calquer                         *}
{*          PHYSP : La page physique dans le Page Frame.              *}
{* Sortie : FALSE en cas d'erreur, sinon TRUE.                        *}
{**********************************************************************}

function EmsMap(Handle, LogP : integer; PhysP : byte) : boolean;

var Regs : Registers;   { Registres processeur pour appel interruption }
begin
  Regs.ah := $44;                             { Nø fct.: Fixer Mapping }
  Regs.al := PhysP;                              { Fixer page physique }
  Regs.bx := LogP;                                { Fixer page logique }
  Regs.dx := Handle;                                { Fixer Handle EMS }
  Intr(EMS_INT, Regs);                                   { Appeler EMM }
  EmmEC := Regs.ah;                             { Ranger code d'erreur }
  EmsMap := (Regs.ah = 0)              { Renvoyer TRUE si pas d'erreur }
end;

{**********************************************************************}
{* EmsFree : LibŠre … nouveau la m‚moire allou‚e sous un Handle       *}
{* Entr‚e : HANDLE: Le Handle fourni par EmsAlloc.                    *}
{* Sortie : FALSE en cas d'erreur, sinon TRUE.                        *}
{**********************************************************************}

function EmsFree(Handle : integer) : boolean;

var Regs : Registers;   { Registres processeur pour appel interruption }

begin
  Regs.ah := $45;                             { Nø fct.: Lib‚rer pages }
  Regs.dx := handle;                                { Fixer Handle EMS }
  Intr(EMS_INT, Regs);                                   { Appeler EMM }
  EmmEC := Regs.ah;                             { Ranger code d'erreur }
  EmsFree := (Regs.ah = 0)             { Renvoyer TRUE si pas d'erreur }
end;

{**********************************************************************}
{* EmsVersion: D‚termine le num‚ro de version de l'EMM                *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : EMS_ERR en cas d'erreur, sinon le num‚ro de version.      *}
{*          11 signifie 1.1, 40 signifie 4.0 etc.                     *}
{**********************************************************************}

function EmsVersion : integer;

var Regs : Registers;   { Registres processeur pour appel interruption }

begin
  Regs.ah := $46;                    { Nø fct.: D‚terminer version EMM }
  Intr(EMS_INT, Regs);                                   { Appeler EMM }
  if (Regs.ah <>0 ) then               { Une erreur est-elle apparue ? }
    begin                                                        { Oui }
      EmmEC := Regs.ah;                      { Ranger le code d'erreur }
      EmsVersion := EMS_ERR;                       { Afficher l'erreur }
    end
  else   { Pas d'erreur, calculer num‚ro de version d'aprŠs nombre BCD }
   EmsVersion := (Regs.al and 15) + (Regs.al shr 4) * 10;
end;

{**********************************************************************}
{* EmsSaveMap: Sauvegarde calquage entre pages logiques et physiques  *}
{*             pour le Handle transmis.                               *}
{* Entr‚e : HANDLE: Le Handle fourni par EmsAlloc.                    *}
{* Sortie : FALSE en cas d'erreur, sinon TRUE.                        *}
{**********************************************************************}

function EmsSaveMap( Handle : integer ) : boolean;

var Regs : Registers;   { Registres processeur pour appel interruption }

begin
  Regs.ah := $47;                       { Nø fct.: Sauvegarder Mapping }
  Regs.dx := handle;                                { Fixer Handle EMS }
  Intr(EMS_INT, Regs);                                   { Appeler EMM }
  EmmEC := Regs.ah;                             { Ranger code d'erreur }
  EmsSaveMap := (Regs.ah = 0)          { Renvoyer TRUE si pas d'erreur }
end;

{**********************************************************************}
{* EmsRestoreMap: R‚tablit le calquage entre pages logiques et        *}
{*                physiques tel qu'il avait ‚t‚ sauvegard‚ auparavant *}
{*                avec EmsSaveMap.                                    *}
{* Entr‚e : HANDLE: Le Handle fourni par EmsAlloc.                    *}
{* Sortie : FALSE en cas d'erreur, sinon TRUE.                        *}
{**********************************************************************}

function EmsRestoreMap( Handle : integer ) : boolean;

var Regs : Registers;   { Registres processeur pour appel interruption }

begin
  Regs.ah := $48;                          { Nø fct.: R‚tablir Mapping }
  Regs.dx := handle;                                { Fixer Handle EMS }
  Intr(EMS_INT, Regs);                                   { Appeler EMM }
  EmmEC := Regs.ah;                             { Ranger code d'erreur }
  EmsRestoreMap := (Regs.ah = 0)       { Renvoyer TRUE si pas d'erreur }
end;

{**********************************************************************}
{* PrintErr: Sort un message d'erreur EMS et termine le programme.    *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : Aucune                                                    *}
{* Infos   : Cette fonction ne doit ˆtre appel‚e que si une erreur a  *}
{*           ‚t‚ signal‚e lors d'un appel pr‚alable d'une fonction de *}
{*           ce module.                                               *}
{**********************************************************************}

procedure PrintErr;

begin
  writeln('ATTENTION ! Erreur d''accŠs … la m‚moire EMS');
  write('     ... ');
  if ((EmmEC<$80) or (EmmEc>$8E) or (EmmEc=$82)) then
    writeln('non identifiable')
  else
    case EmmEC of
      $80 : writeln('Erreur dans le driver EMS (EMM d‚truit)');
      $81 : writeln('Erreur dans l''‚lectronique EMS');
      $83 : writeln('Handle EMM incorrect');
      $84 : writeln('Fonction EMS appel‚e n''existe pas');
      $85 : writeln('Plus de handles EMS disponibles');
      $86 : writeln('Erreur de sauvegarde ou de reconstitution ',
                    'du Mapping');
      $87 : writeln('Plus de pages r‚clam‚es qu''il n''en existe ',
                    'physiquement');
      $88 : writeln('Plus de pages r‚clam‚es qu''il n''en reste',
                     ' de libres');
      $89 : writeln('Z‚ro page r‚clam‚e');
      $8A : writeln('Page logique ne correspondant pas au Handle');
      $8B : writeln('Num‚ro de page physique incorrect');
      $8C : writeln('Zone de m‚moire de Mapping pleine');
      $8D : writeln('Sauvegarde du Mapping d‚j… effectu‚e');
      $8E : writeln('Reconstituation du Mapping sans ',
                    'sauvegarde ant‚rieure');
    end;
  Halt;                                           { Terminer programme }
end;

{**********************************************************************}
{* VrAdr: Fournit un pointeur sur la RAM vid‚o.                       *}
{* Entr‚e : Aucune                                                    *}
{* Sortie : Pointeur sur la RAM vid‚o.                                *}
{**********************************************************************}

function VrAdr : BytePtr;

var Regs : Registers;   { Registres processeur pour appel interruption }

begin
  Regs.ah := $0f;                     { Nø fct.: D‚terminer mode vid‚o }
  Intr($10, Regs);                { Appeler interruption vid‚o du BIOS }
  if (Regs.al = 7) then                   { Carte d'‚cran monochrome ? }
    VrAdr := ptr($B000, 0)               { Oui, RAM vid‚o en B000:0000 }
  else                                     { Carte couleur, EGA ou VGA }
    VrAdr := ptr($B800, 0);                   { RAM vid‚o en B800:0000 }
end;

{**********************************************************************}
{* PageAdr: Fournit l'adresse d'une page physique dans le Page Frame  *}
{* Entr‚e : PAGE: Num‚ro de page physique (0 … 3)                     *}
{* Sortie : Pointeur sur la page physique.                            *}
{**********************************************************************}

function PageAdr( Page : integer ) : BytePtr;

begin
  PageAdr := ptr( EmsFrameSeg + (Page shl 10), 0 );
end;

{**********************************************************************}
{**                       PROGRAMME PRINCIPAL                        **}
{**********************************************************************}

begin
  ClrScr;                                              { Vider l'‚cran }
  writeln('EMMP - (c) 1988, 92 by MICHAEL TISCHER',#13#10);
  if EmsInst then                            { M‚moire EMS install‚e ? }
    begin                                                        { Oui }
       {*-- Sortir informations sur la m‚moire EMS -------------------*}

      EmmVer := EmsVersion;         { D‚terminer num‚ro de version EMM }
      if EmmVer = EMS_ERR then         { Une erreur est-elle apparue ? }
        PrintErr; { Oui, sortir message d'erreur et terminer programme }
      writeln('Num‚ro de version EMM        : ',EmmVer div 10, '.',
              EmmVer mod 10);

      NmbPage := EmsNumPage;        { D‚terminer nombre total de pages }
      if NmbPage = EMS_ERR then        { Une erreur est-elle apparue ? }
        PrintErr; { Oui, sortir message d'erreur et terminer programme }
      writeln('Nombre de pages EMS          : ', NmbPage, ' (',
               NmbPage shl 4, ' Ko)');

      NmbPage := EmsFreePage;      { D‚terminer nombre de pages libres }
      if NmbPage = EMS_ERR then        { Une erreur est-elle apparue ? }
        PrintErr; { Oui, sortir message d'erreur et terminer programme }
      writeln('... dont libres              : ', NmbPage, ' (',
               NmbPage shl 4, ' Ko)');

      PageSeg := EmsFrameSeg;       { Adresse de segment du Page Frame }
      if PageSeg = W_EMS_ERR then      { Une erreur est-elle apparue ? }
        PrintErr; { Oui, sortir message d'erreur et terminer programme }
      writeln('Adresse de segment du Page Frame: ', EmsFrameSeg );

      writeln;
      writeln('On alloue maintenant une page de la m‚moire EMS et');
      writeln('le contenu de l''‚cran est copi‚ de la RAM vid‚o');
      writeln('dans cette page.');
      writeln('                     ... veuillez actionner une Touche');
      Touche := ReadKey;                         { Attendre une touche }

      {*-- Allouer une page et la calquer sur la premiŠre page  ------*}
      {*-- logique dans le Page Frame                           ------*}

      Handle := EmsAlloc( 1 );                      { Allouer une page }
      if Handle = EMS_ERR then         { Une erreur est-elle apparue ? }
        PrintErr; { Oui, sortir message d'erreur et terminer programme }
      if not(EmsMap(Handle, 0, 0)) then                { Fixer Mapping }
        PrintErr;              { Erreur : message d'erreur et terminer }

      {*-- Copier 4000 octets de la RAM vid‚o dans la m‚moire EMS ----*}

      Move(VrAdr^, PageAdr(0)^, 4000);

      ClrScr;                                          { Vider l'‚cran }
      while KeyPressed do                     { Lire le buffer clavier }
        Touche := ReadKey;
      writeln('L''ancien contenu de l''‚cran a maintenant ‚t‚ vid‚ et');
      writeln('est donc d‚finitivement perdu. Mais comme il avait ‚t‚');
      writeln('sauvegard‚ dans la m‚moire EMS, il peut ˆtre recopi‚');
      writeln('de l… dans la RAM vid‚o.');
      writeln('                     ... Veuillez actionner une Touche');
      Touche := ReadKey;                         { Attendre une touche }

        {*-- Recopier le contenu de la RAM vid‚o d'aprŠs la m‚moire --*}
        {*-- EMS et lib‚rer … nouveau la m‚moire EMS allou‚e        --*}

      Move(PageAdr(0)^, VrAdr^, 4000);            { Recopier RAM vid‚o }
      if not(EmsFree(Handle)) then                   { Lib‚rer m‚moire }
        PrintErr;              { Erreur : message d'erreur et terminer }
      GotoXY(1, 15);
      writeln('FIN')
    end
 else                            { Le driver EMS n'a pu ˆtre identifi‚ }
   writeln('ATTENTION ! Pas de m‚moire EMS install‚e.');
end.
