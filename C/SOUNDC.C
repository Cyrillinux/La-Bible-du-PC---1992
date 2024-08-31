/**********************************************************************/
/*                             S O U N D C                            */
/*--------------------------------------------------------------------*/
/*    Fonction       : Sortie de la gamme chromatique des octaves 3   */
/*                     … 5 … l'aide d'une fonction assembleur         */
/*--------------------------------------------------------------------*/
/*    Auteur         : MICHAEL TISCHER                                */
/*    d‚velopp‚ le   : 15/08/1987                                     */
/*    derniŠre modif.: 29/04/1989                                     */
/*--------------------------------------------------------------------*/
/*    (MICROSOFT C)                                                   */
/*    Cr‚ation       : CL /AS SOUNDC.C SOUNDA                         */
/*    Appel          : SOUNDc                                         */
/*--------------------------------------------------------------------*/
/*    (BORLAND TURBO C)                                               */
/*    Cr‚ation       : Avec fichier Project de la teneur suivante :   */
/*                     soundc                                         */
/*                     soundca.obj                                    */
/**********************************************************************/

/*== D‚claration des fonctions du module assembleur ==================*/
extern void Sound();           /* Pour int‚grer la routine assembleur */

/**********************************************************************/
/**                       PROGRAMME PRINCIPAL                        **/
/**********************************************************************/

void main()

{
 int Son;

 printf("\nSOUND (c) 1987 by Michael Tischer\n\n");
 printf("Si le haut-parleur de votre PC fonctionne correctement, vous");
 printf(" allez entendre\nmaintenant la gamme entre les octaves 3 et ");
 printf("5, chaque note ‚tant jou‚e\npendant une demie seconde.\n\n");
 for (Son = 0; Son < 35; Sound(Son++, 9))    /* Jouer chaque note une */
  ;                                          /* demie seconde         */

 printf("Fin\n");
}
