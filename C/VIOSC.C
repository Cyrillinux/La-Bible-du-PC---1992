/**********************************************************************/
/*                               V I O S C                            */
/*--------------------------------------------------------------------*/
/*    Fonction       : D‚termine le type de cartes vid‚o              */
/*                     install‚es et les moniteurs connect‚s          */
/*--------------------------------------------------------------------*/
/*    Auteur         : MICHAEL TISCHER                                */
/*    D‚velopp‚ le   :  2.10.1988                                     */
/*    DerniŠre MAJ   : 14.02.1992                                     */
/*--------------------------------------------------------------------*/
/*    (MICROSOFT C)                                                   */
/*    Compilation    : CL /AS /c VIOSC.C VIOSCA                       */
/*    Appel          : VIOSC                                          */
/*--------------------------------------------------------------------*/
/*    (BORLAND TURBO C)                                               */
/*    Compilation : avec un fichier de projet dont le contenu est :   */
/*                     VIOSC                                          */
/*                     VIOSCA.OBJ                                     */
/**********************************************************************/

#include <stdio.h>

/*== D‚claration de fonctions externes ===============================*/

extern void get_vios( struct vios * );

/*== Typedef =========================================================*/
                                                                        
typedef unsigned char BYTE;               /* Bricolage d'un type BYTE */
                                                                        
/*== Structures ======================================================*/
                                                                        
struct vios {       /* D‚crit une carte vid‚o et le moniteur connect‚ */
             BYTE carte,
                  moniteur;
            };
                                                                        
/*== Constantes ======================================================*/

/*-- Constantes pour la carte vid‚o ----------------------------------*/

#define NO_VIOS    0                            /* Pas de carte vid‚o */
#define VGA        1                                      /* Carte VGA*/
#define EGA        2                                      /* Carte EGA*/
#define MDA        3                    /* Monochrome Display Adapter */
#define HGC        4                                /* Carte Hercules */
#define CGA        5                        /* Color Graphics Adapter */
                                                                        
/*-- Constantes pour le type de moniteur------------------------------*/

#define NO_MON     0                               /* Pas de moniteur */
#define MONO       1                            /* Moniteur monochrome*/
#define COLOR      2                              /* Moniteur couleur */
#define EGA_HIRES  3                  /* Moniteur … haute r‚soluation */
#define ANAL_MONO  4                /* Moniteur monochrome analogique */
#define ANAL_COLOR 5                   /* Moniteur couleur analogique */
                                                                        
/**********************************************************************/
/**                    PROGRAMME PRINCIPAL                           **/
/**********************************************************************/
                                                                        
void main()

{
 static char *nomscvi[] = { /* Pointeur sur les noms des cartes vid‚o */
                           "VGA",
                           "EGA",
                           "MDA",
                           "HGC",
                           "CGA"
                          };

 static char *nomsmoni[] = {   /* Pointeur sur les types de moniteurs */
                            "Moniteur monochrome",
                            "Moniteur couleur",
                            "Moniteur haute r‚solution",
                            "Moniteur monochrome analogique",
                            "Moniteur couleur analogique"
                           };

 struct vios vsys[2];                        /* Vecteur pour GET_VIOS */

 get_vios( vsys );                      /* D‚termine le systŠme vid‚o */
 printf("\nVIOSC (c) 1988, 92 by Michael Tischer\n\n");
 printf("SystŠme vid‚o primaire :   carte %s sur %s\n",
         nomscvi[vsys[0].carte-1], nomsmoni[vsys[0].moniteur-1]);
 if ( vsys[1].carte != NO_VIOS )        /* SystŠme vid‚o secondaire ? */
   printf("SystŠme vid‚o secondaire : carte %s sur %s\n",
           nomscvi[vsys[1].carte-1], nomsmoni[vsys[1].moniteur-1]);
}

