/**********************************************************************/
/*                             T Y P M C                              */
/*--------------------------------------------------------------------*/
/*    Fonction       : Permet de choisir la vitesse Typematic         */
/*                     d'un clavier ‚tendu                            */
/*--------------------------------------------------------------------*/
/*    Auteur                : MICHAEL TISCHER                         */
/*    d‚velopp‚ le          : 28.08.1988                              */
/*    DerniŠre modification : 03.01.1992                              */
/*--------------------------------------------------------------------*/
/*    ModŠle m‚moire : SMALL                                          */
/*--------------------------------------------------------------------*/
/*    Modules        : TYPMC.C + TYPMCA.ASM                           */
/**********************************************************************/

/*== Fichiers d'inclusion ============================================*/

#include <stdlib.h>
#include <stdio.h>

/*== Typedefs ========================================================*/

typedef unsigned char BYTE;               /* Bricolage d'un type Byte */
typedef BYTE BOOL;                   /* Prend la valeur TRUE ou FALSE */

/*== Constantes ======================================================*/

#define TRUE  ( 1 == 1 )                   /* Constantes de type BOOL */
#define FALSE ( 0 == 1 )

/*== Inclusion de fonctions externes issues du module en assembleur ==*/

extern BOOL set_typm( BYTE trate );      /* Fixe la vitesse Typematic */

/**********************************************************************/
/**                         Programme principal                       */
/**********************************************************************/

void main(int argc, char *argv[] )
{
 int delay,                                      /* M‚morise le d‚lai */
     speed;                          /* et la fr‚quence de r‚p‚tition */

 printf("\nTYPMC  -  (c) 1988, 1992 by MICHAEL TISCHER\n");
 if (argc!=3 || ( (delay = atoi(argv[1]))<0 || delay>3 ) ||
		( (speed = atoi(argv[2]))<0 || speed>31 ))
  {               /* Il n'y a pas deux paramŠtres ou ils sont faux    */
   printf("Appel : TYPMC D‚lai Vitesse \n");
   printf("                \x1e        \x1e\n");
   printf("                ³        ³\n");
   printf("ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍ»  ÉÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ»\n");
   printf("º  0 : 1/4 Seconde  º  º  0 : 30,0 r‚p./s. º\n");
   printf("º  1 : 1/2 Seconde  º  º  1 : 26,7 r‚p./s. º\n");
   printf("º  2 : 3/4 Seconde  º  º  2 : 24,0 r‚p./s. º\n");
   printf("º  3 : 1 Seconde    º  º  3 : 21,8 r‚p./s. º\n");
   printf("ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶  º         .         º\n");
   printf("º Pr‚cision    ñ20%% º  º         .         º\n");
   printf("ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼  º         .         º\n");
   printf("                       º 28 :  2,5 r‚p./s. º\n");
   printf("                       º 29 :  2,3 r‚p./s. º\n");
   printf("                       º 30 :  2,1 r‚p./s. º\n");
   printf("                       º 31 :  2,0 r‚p./s. º\n");
   printf("                       ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼\n");
  }
 else  /* Les paramŠtres sont corrects */
  {
   if (set_typm( (BYTE) ((delay << 5) + speed ))) /* Fixe la vitesse Typematic */
    printf("La vitesse Typematic a ‚t‚ fix‚e .\n");
   else
    printf("ATTENTION ! Erreur d'accŠs au contr“leur du clavier\n");
  }
}
