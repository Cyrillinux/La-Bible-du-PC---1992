/**********************************************************************/
/*                               D D P T C                            */
/*--------------------------------------------------------------------*/
/*    Fonction       : Permet d'optimiser les accŠs … la disquette    */
/*                     en modifiant les valeurs de la Disk-Drive-     */
/*                     Parameter-Table.                               */
/*--------------------------------------------------------------------*/
/*    Auteur                : Michael Tischer                         */
/*    D‚velopp‚ le          : 22.08.1991                              */
/*    DerniŠre modification : 22.09.1991                              */
/**********************************************************************/

/*== Int‚grer les fichiers Include  ==================================*/

#include <dos.h>
#include <stdio.h>
#include <io.h>
#include <string.h>

/*== Macros ==========================================================*/

#ifdef MK_FP                             /* Macro MK_FP d‚j… d‚finie? */
  #undef MK_FP                            /* Si oui, effacer la macro */
#endif

#define MK_FP(seg,ofs) ((void far *) ((unsigned long) (seg)<<16|( ofs)))

/*== Typedefs ========================================================*/

typedef unsigned char byte;               /* Octet de type de donn‚es */
typedef byte DDPT_Typ[ 11 ];                   /* Champ pour une DDPT */

/**********************************************************************/
/* upcase       : Convertit une lettre en majuscule                   */
/* Entr‚e       : Lettre                                              */
/* Sortie       : Majuscule                                           */
/**********************************************************************/

byte upcase( letter )
byte letter;

{
 if ( ( letter > 0x60 ) && ( letter < 0x7B ) )          /* Convertir? */
  return( letter & 0xDF );                     /* Oui, masquer le bit */
 else
  return( letter);                         /* Non, retourner tel quel */
}

/**********************************************************************/
/* D_Chiffre : Convertit un chiffre hexad‚cimal en une valeur         */
/*             d‚cimale                                               */
/* Entr‚e    : Chiffre hexad‚cimal                                    */
/* Sortie    : Nombre                                                 */
/**********************************************************************/

byte D_Chiffre( Hex )
char Hex;

{
 if ( ( Hex >= 0x41 ) && ( Hex <= 0x46 ) )                  /* A - F? */
  return( Hex - 55 );                                          /* Oui */
 else
  return( Hex ) - 48;                               /* Non, donc 0..9 */
}

/**********************************************************************/
/* hex_byte : Convertit une chaŒne hexa en un octet                   */
/* Entr‚e   : Voir plus bas                                           */
/* Sortie   : Nombre                                                  */
/**********************************************************************/

byte hex_byte( hex )
char *hex;                                 /* ChaŒne hexa … convertir */

{
 if ( hex[ 1 ] == 0x58 )              /* Tester si X donc Nombre 0x.. */
   hex += 2;                              /* Pointeur sur 1er chiffre */
 return( ( D_Chiffre( *hex ) << 4 ) | D_Chiffre( hex[ 1 ] ) );
}

/**********************************************************************/
/* GetIntVec     : Lit un vecteur d'interruption                      */
/* Entr‚e        : Num‚ro d'interruption                              */
/* Sortie        : Vecteur d'interruption                             */
/**********************************************************************/

void far *GetIntVec( Numero )
int Numero;

{
 return( * ( void far * far * ) ( MK_FP( 0, Numero * 4 ) ) );
}

/**********************************************************************/
/* RAM_DDPT : Tester si DDPT se trouve dans la RAM ou la ROM          */
/* Entr‚e   : Voir plus bas                                           */
/* Sortie   : true si DDPT dans la RAM                                */
/* Infos    : La fonction inscrit une valeur dans la DDPT, la relit   */
/*            puis compare si la valeur a ‚t‚ inscrite, la DDPT se    */
/*            trouve donc dans la RAM                                 */
/**********************************************************************/

int RAM_DDPT( DDPT )
DDPT_Typ far *DDPT;                              /* Pointeur sur DDPT */

{
 byte buffer;           /* M‚moire pour la valeur actuelle de la DDPT */
 int  Flag;                       /* M‚moire pour la valeur de retour */

 buffer = *DDPT[ 0 ];                   /* Sauvegarder la valeur DDPT */
 *DDPT[ 0 ] = buffer ^ 0xFF;                    /* Inverser la valeur */
 Flag = ( *DDPT[ 0 ] == ( buffer ^0xFF ) );
 *DDPT[ 0 ] = buffer;                  /* Restaurer l'ancienne valeur */
 return( Flag );                                  /* Valeur de retour */
}

/**********************************************************************/
/* AfficherValeur : Afficher la valeur DDPT                           */
/* Entr‚e         : Voir plus bas.                                    */
/* Sortie         : Aucune                                            */
/* Infos          : La proc‚dure affiche la valeur actuelle de la     */
/*                  DDPT sur l'‚cran.                                 */
/**********************************************************************/

void AfficherValeur( DDPT )
DDPT_Typ far *DDPT;                              /* Pointeur sur DDPT */

{
  printf( "Steprate                (SR): 0x%02x\n\n",
	  ( *DDPT )[ 0 ] >> 4 );
  printf( "Head-Unload-Time        (HU): 0x%02x\n",
	  ( *DDPT )[ 0 ] & 0x0f );
  printf( "Head-Load-Time          (HL): 0x%02x\n",
	  ( *DDPT )[ 1 ] >> 1 );
  printf( "Head-Settle-Time        (HS): 0x%02x\n\n", ( * DDPT )[ 9 ] );
  printf( "Temps de rotation du moteur aprŠs (MN): 0x%02x\n",
						       ( *DDPT )[ 2 ] );
  printf( "Temps de rotation du moteur avant   (MA): 0x%02x\n",
						      ( *DDPT )[ 10 ] );
}

/**********************************************************************/
/* ValeursNouv : D‚finir les nouvelles valeurs DDPT                   */
/* Entr‚e      : Voir plus bas                                        */
/* Sortie      : Aucune                                               */
/**********************************************************************/

void ValeursNouv( Nombre, Valeurs, DDPT )
int Nombre;                                    /* Nombre de commandes */
char *Valeurs[];                              /* Champ avec commandes */
DDPT_Typ far *DDPT;                              /* Pointeur sur DDPT */

{
 int i,j;                                       /* Compteur de boucle */
 char Art[ 4 ],                               /* ParamŠtre … modifier */
      Commande[ 8 ];          /* ParamŠtres de la ligne d'instruction */
 byte Valeur,                            /* Nouvelle valeur … d‚finir */
      ValSecours;                  /* Valeur de secours … sauvegarder */

 /*-- Boucle: Examiner tous les paramŠtres ---------------------------*/

 for ( i = 1; i < Nombre; i++ )
 {
  strcpy( Commande, Valeurs[ i ] );              /* Lire le paramŠtre */
  j = 0;
  while ( Commande[ j ] != 0 )
   Commande[ j++ ] = upcase( Commande[ j ] );

  Art[ 0 ] = Commande[ 0 ];                    /* ParamŠtre … d‚finir */
  Art[ 1 ] = Commande[ 1 ];
  Art[ 2 ] = 0;
  Valeur = hex_byte( &Commande[ 3 ] );            /* Valeur … d‚finir */
  if ( !strcmp( Art, "SR" ) )                           /* Step rate? */
   {
    Valeur = Valeur << 4;         /* Valeur dans le quartet sup‚rieur */
    ValSecours = ( *DDPT )[ 0 ] & 0x0F;  /* Lire le quartet inf‚rieur */
    ( *DDPT )[ 0 ] = Valeur | ValSecours;         /* Ecrire la valeur */
   }
  else if ( !strcmp( Art, "HU" ) )               /* Head-Unload-Time? */
   {
    Valeur = Valeur & 0x0F;       /* Valeur dans le quartet inf‚rieur */
    ValSecours = ( *DDPT )[ 0 ] & 0xF0;  /* Lire le quartet sup‚rieur */
    ( *DDPT )[ 0 ] = Valeur | ValSecours;         /* Ecrire la valeur */
   }
  else if ( !strcmp( Art, "HL" ) )                 /* Head-Load-Time? */
   ( *DDPT )[ 1 ] = Valeur << 1; /* Sauve la valeur dans les bits 1-7 */
  else if ( !strcmp( Art, "HS" ) )               /* Head-Settle-Time? */
   ( *DDPT )[ 9 ] = Valeur;                  /* Sauvegarder la valeur */
  else if ( !strcmp( Art, "MN" ))/* Temps de rotation du moteur avant */
   ( *DDPT )[ 2 ] = Valeur;                  /* Sauvegarder la valeur */
  else if ( !strcmp( Art, "MA" ))/* Temps de rotation du moteur aprŠs */
   ( *DDPT )[ 10 ] = Valeur;                 /* Sauvegarder la valeur */
 }
}

/**********************************************************************/
/*                         PROGRAMME PRINCIPAL                        */
/**********************************************************************/

void main( argc, argv )
int argc;
char *argv[];

{
 DDPT_Typ far *DDPT;                 /* Pointeur sur la DDPT actuelle */

 printf( "DPPTC (c) 1991, 1992 by Michael Tischer\n" );
 printf( "Optimiser les accŠs … la disquette\n" );

 DDPT = GetIntVec( 0x1E );            /* Lire le pointeur sur la DDPT */

 if ( RAM_DDPT )                /* DDPT dans la RAM, donc modifiable? */
  {
   if ( argc > 1 )                    /* Faut-il d‚finir les valeurs? */
    {
     ValeursNouv( argc, argv, DDPT );/* D‚finir les nouvelles valeurs */
     printf( "\n\nNouvelles valeurs de la DDPT:\n" );
     AfficherValeur( DDPT );/* Afficher les nouvelles valeurs de DDPT */
    }
  }
 else           /* DDPT se trouve dans la ROM, impossible de modifier */
  printf( "%s %s ", "Il est impossible de modifier la ",
	  "Disk-Drive-Parameter-Table car elle se trouve dans la ROM" );
   printf( "\nContenu DDPT:\n" );
 AfficherValeur( DDPT );/* Afficher les anciennes valeurs de la DDPT  */
}
