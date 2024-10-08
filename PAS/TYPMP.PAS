{**********************************************************************}
{*                              T Y P M P                             *}
{*--------------------------------------------------------------------*}
{*    Fixe la vitesse Typematic d'un clavier �tendu                   *}
{*--------------------------------------------------------------------*}
{*    Auteur                : MICHAEL TISCHER                         *}
{*    D�velopp� le          : 27.08.1988                              *}
{*    Derni�re modification : 03.01.1992                              *}
{**********************************************************************}

program TYPMP;

{**********************************************************************}
{* SetTypm : Transmet la vitesse Typematic au contr�leur du clavier   *}
{* Entr�e  : RATE : Vitesse � fixer                                   *}
{* Sortie  : TRUE, si la vitesse a pu �tre fix�                       *}
{*           FALSE en cas d'erreur d'acc�s au contr�leur              *}
{* Info    : Cette fonction peut �tre incluse dans une unit�          *}
{**********************************************************************}

{$F+}                                    { Exploite le mod�le FAR-Call }

function SetTypm( Rate : byte ) : boolean;

begin
 inline(
        $32/$D2/$B4/$F3/$FA/$E8/$13/$00/$75/$0A/$8A/$66/$06/$E8/
        $0B/$00/$75/$02/$FE/$C2/$FB/$88/$56/$FF/$EB/$27/$90/$51/
        $53/$B3/$03/$33/$C9/$E4/$64/$A8/$02/$E0/$FA/$8A/$C4/$E6/
        $60/$E4/$64/$A8/$01/$E1/$FA/$E4/$60/$3C/$FA/$74/$07/$FE/
        $CB/$75/$E6/$80/$CB/$01/$5B/$59/$C3
       );
end;

{$F-}

{**********************************************************************}
{**                Programme principal                               **}
{**********************************************************************}

var  Delay,                                        { M�morise le d�lai }
     Speed,                            { et la fr�quence de r�p�tition }
     Fpos1,
     FPos2   : integer;               { Erreur de conversion de cha�ne }
     ParErr : boolean;         { Erreur de transmission des param�tres }

begin
  writeln(#13#10,'TYPMP  -  (c) 1988, 1992 by MICHAEL TISCHER');
  ParErr := true;                            { Saisie a priori erron�e }
  if ParamCount = 2 then              { Dispose-t-on de 2 param�tres ? }
    begin                                                        { Oui }
      val(ParamStr(1), Delay, FPos1);           { Conversion en entier }
      val(ParamStr(2), Speed, FPos2);                {  des param�tres }
      if ((FPos1=0) and (FPos2=0)) then       { Erreur de conversion ? }
	if ((Delay < 4) and (Speed <32)) then      { Non tout va bien  }
	  ParErr := false;              { Les param�tres sont corrects }
    end;
  if ( ParErr ) then                    { En cas d'erreur de param�tre }
    begin
      writeln('Appel : TYPMP  D�lai Vitesse ');
      writeln('                ',#30,'        ',#30);
      writeln('                �        �');
      writeln('�������������������ͻ  �������������������ͻ');
      writeln('�  0 : 1/4 seconde  �  �  0 : 30,0 r�p./s  �');
      writeln('�  1 : 1/2 seconde  �  �  1 : 26,7 r�p./s. �');
      writeln('�  2 : 3/4 seconde  �  �  2 : 24,0 r�p./s. �');
      writeln('�  3 : 1 seconde    �  �  3 : 21,8 r�p./s. �');
      writeln('�������������������Ķ  �         .         �');
      writeln('� Pr�cision    �20% �  �         .         �');
      writeln('�������������������ͼ  �         .         �');
      writeln('                       � 28 :  2,5 r�p./s. �');
      writeln('                       � 29 :  2,3 r�p./s. �');
      writeln('                       � 30 :  2,1 r�p./s. �');
      writeln('                       � 31 :  2,0 r�p./s. �');
      writeln('                       �������������������ͼ');
    end
  else                                  { Les param�tres sont corrects }
  begin
    if (SetTypm( (Delay shl 5) + Speed )) then { Fixe vitesse Typematic}
      writeln('La vitesse Typematic a �t� fix�e .')
    else
      writeln('ATTENTION: Erreur d''acc�s au contr�leur');
  end;
end.
