/**********************************************************************/
/*                               P R O C C                            */
/*--------------------------------------------------------------------*/
/*    Fonction        : DÇtermine le type du processeur d'un PC       */
/*--------------------------------------------------------------------*/
/*    Auteur          : MICHAEL TISCHER                               */
/*    DÇveloppÇ le    : 14.08.1988                                    */
/*    Derniäre modif. : 10.02.1992                                    */
/*--------------------------------------------------------------------*/
/*    (MICROSOFT C)                                                   */
/*    CrÇation     : CL /AS /c PROCC.C                                */
/*                     LINK PROCC PROCCA                              */
/*    Appel         : PROCC                                           */
/*--------------------------------------------------------------------*/
/*    (BORLAND TURBO C)                                               */
/*    CrÇation       : Avec un fichier Project de teneur suivante :   */
/*                     PROCC.C                                        */
/*                     PROCCA.ASM                                     */
/**********************************************************************/

#include <stdio.h>

extern int getproc( void );    /* Pour intÇgrer la routine Assembleur */
extern int getco( void );

/**********************************************************************/
/**                       PROGRAMME PRINCIPAL                        **/
/**********************************************************************/

void main()

{
 static char * procname[] = {  /* Vecteur avec pointeurs sur les noms */
                             "Intel 8088",                  /* Code 0 */
                             "Intel 8086",                  /* Code 1 */
                             "NEC V20",                     /* Code 2 */
                             "NEC V30",                     /* Code 3 */
                             "Intel 80188",                 /* Code 4 */
                             "Intel 80186",                 /* Code 5 */
                             "Intel 80286",                 /* Code 6 */
                             "i386",                        /* Code 7 */
                             "i486"                         /* Code 8 */
                            };

 
 static char * coproc[]   = {               /* noms des coprocesseurs */
                             "aucun",                       /* Code 0 */
                             "8087",                        /* Code 1 */
                             "80287",                       /* Code 2 */
                             "i387/i487"                    /* Code 3 */
                            };
 
 printf("€€€€€€€€€€€€ PROCC (c) 1988, 92 by Michael Tischer €€€\n\n");
 printf("Votre PC est ÇquipÇ d'un processeur %s.\n",
        procname[ getproc() ] );
 printf("Coprocesseur : %s.\n\n", coproc[ getco() ] );
}
