//+------------------------------------------------------------------+
//|                                                          Fimathe |
//|                                                           uriS$e |
//+------------------------------------------------------------------+

#include <isNewBar.mqh>
#include <Trade/Trade.mqh>

#include <Graphics\Graphic.mqh>

#define  numero_particoes 50
int posicoes[];
double valores[];
double canalMediano;
double alturaReferencia;
int tamanho;

CTrade trade;

input int numeroMagico = 1234;
input int numero_candles = 2000;

enum SINAL {
   SINAL_NENHUM,
   SINAL_COMPRA,
   SINAL_VENDA
};

SINAL sinal;
double preco_entrada;
double preco_rompido;
double preco_stop;
double preco_espera;
double preco_take;

int ticket_atual;

int nivel_do_surfe;

double margem_stop = 2.2;
double margem_take = 3.8;
double desconto_do_stop_no_surfe = .15;

int topo_atual;
int topo_anterior;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit() {
   trade.SetExpertMagicNumber(numeroMagico);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
   if(!isNewBar())
      return;

//Trabalha com fechamentos
   if(!verificaPosicoes()) {
      apagaEspera();

      ArrayResize(posicoes, 2);
      ArrayResize(valores, 2);

      posicoes[0] = 0;
      posicoes[1] = numero_candles;
      valores[0] = iClose(_Symbol, PERIOD_CURRENT, 0);
      valores[1] = iClose(_Symbol, PERIOD_CURRENT, numero_candles);

      for (int j = 0; j < numero_particoes; j++) {
         double maximaDistancia = -1;
         int posicaoMaximaDistancia = -1;

         for (int i = 0; i < numero_candles; i++) {

            double distancia = distancia_absoluta_tracado(i, iOpen(_Symbol, PERIOD_CURRENT, i));
            //Print("Distancia");
            //Print(distancia);
            if(distancia > maximaDistancia) {
               maximaDistancia = distancia;
               posicaoMaximaDistancia = i;
            }
         }
         insereOrdenado(posicaoMaximaDistancia, iOpen(_Symbol, PERIOD_CURRENT,  posicaoMaximaDistancia));
      }
      desenharLinhas();

      double distancias[];
      double alturas[];
      ArrayResize(distancias, ArraySize(posicoes) - 3);
      ArrayResize(alturas, ArraySize(posicoes) - 3);

      ArrayCopy(alturas, valores, 0, 1, ArraySize(posicoes) - 1);
      ArraySort(alturas);
      //Print("Alturas");
      //ArrayPrint(alturas);
      for(int i = 1; i < ArraySize(posicoes) - 3; i++) {
         distancias[i] = MathAbs(valores[i] - valores[i + 1]);
      }
      ArraySort(distancias);
      //Print("Distancias");
      //ArrayPrint(distancias);

      if(distancias[ArraySize(distancias) / 2] != canalMediano) {
         //Print("canal mediano");
         //Print(canalMediano);
      }
      canalMediano = distancias[ArraySize(distancias) / 2];
      //Print("Alturas");
      //ArrayPrint(alturas);

      //alturaReferencia = alturas[ArraySize(alturas) / 2];

      for(int i = 0; i < ArraySize(posicoes) - 1; i++) {
         if(MathAbs(valores[i] - valores[i + 1]) == canalMediano) {
            alturaReferencia = valores[i];
         }
      }

      /*
         CGraphic graphic;
         graphic.Create(0, "Graphic", 0, 30, 30, 780, 380);

         CCurve *curve = graphic.CurveAdd(alturas, 0,CURVE_STEPS);
         graphic.CurvePlotAll();
         graphic.Update();
         */
      DesenhaNiveis();

      //---Testando se houve rompimento
      double ultimo_fechamento = iClose(_Symbol, PERIOD_CURRENT, 1);
      double fechamento_anterior = iClose(_Symbol, PERIOD_CURRENT, 2);
      topo_atual = index_nivel_gerado(ultimo_fechamento);
      topo_anterior = index_nivel_gerado(fechamento_anterior);
      sinal = SINAL_NENHUM;
      if(topo_atual > topo_anterior) {
         //---ROMPEU PARA CIMA
         //Print("Rompeu para cima");
         //Print("topo atual: ", topo_atual, ", topo anterior: ", topo_anterior);
         for(int i = 2; ; i++) {
            double valor_teste = iClose(_Symbol, PERIOD_CURRENT, i);
            if(valor_teste < nivel_gerado(topo_atual - 3)) {
               Print("Rompeu o canal de referência! (para cima)");
               //Print("niveis");
               //ArrayPrint(niveis);
               sinal = SINAL_COMPRA;
               preco_rompido = nivel_gerado(topo_atual - 1);
               break;
            }
            if(valor_teste > nivel_gerado(topo_atual - 1)) {
               //Print("Voltou para a zona neutra");
               break;
            }
         }
      }
      if(topo_atual < topo_anterior) {
         //--ROMPEU PARA BAIXO
         //---Descobrir se rompeu o canal de referencia ou so voltou
         //---para a zona neutra
         //Print("Rompeu para baixo");
         //Print("topo atual: ", topo_atual, ", topo anterior: ", topo_anterior);
         for(int i = 2; ; i++) {
            double valor_teste = iClose(_Symbol, PERIOD_CURRENT, i);
            if(valor_teste > nivel_gerado(topo_atual + 2)) {
               Print("Rompeu o canal de referência! (para baixo)");
               //ArrayPrint(niveis);
               sinal = SINAL_VENDA;
               preco_rompido = nivel_gerado(topo_atual);
               break;
            }
            if(valor_teste < nivel_gerado(topo_atual)) {
               //Print("Voltou para a zona neutra");
               break;
            }
         }
      }
      //---Lógica de negociação
      double volume = 0.01;
      double stop = margem_stop * canalMediano;
      double take = margem_take * canalMediano;
      if(sinal == SINAL_COMPRA) {
         trade.Buy(volume, _Symbol, 0, preco_rompido - stop, preco_rompido + take);
         preco_take = preco_rompido + take;
         preco_espera = preco_rompido + canalMediano;
      }
      if(sinal == SINAL_VENDA) {
         trade.Sell(volume, _Symbol, 0, preco_rompido + stop, preco_rompido - take);
         preco_take = preco_rompido - take;
         preco_espera = preco_rompido - canalMediano;
      }
      if(sinal == SINAL_COMPRA || sinal == SINAL_VENDA) {
         nivel_do_surfe = 0;
         desenhaEspera();
         ticket_atual = trade.ResultOrder();
         preco_entrada = trade.ResultPrice();
         Print("ticket atual:", ticket_atual, " preco entrada:", preco_entrada);
      }
   } else {
      //---Posicionado
      //---Verificação de se é para mover o stop
      double ultimo_fechamento = iClose(_Symbol, PERIOD_CURRENT, 1);
      if(sinal == SINAL_COMPRA && ultimo_fechamento > preco_espera) {
         nivel_do_surfe++;
         if(nivel_do_surfe == 1) {
            //Zero a zero
            Print("Bota no 0/0                  Bota no 0/0");
            preco_stop = preco_entrada;
            trade.PositionModify(ticket_atual, preco_stop, preco_take);
         } else {
            preco_stop = preco_rompido + ((nivel_do_surfe - 1) - desconto_do_stop_no_surfe) * canalMediano;
            trade.PositionModify(ticket_atual, preco_stop, preco_take);
         }
         preco_espera = preco_rompido + (nivel_do_surfe + 1) * canalMediano;
         desenhaEspera();
      }
      if(sinal == SINAL_VENDA && ultimo_fechamento < preco_espera) {
         nivel_do_surfe++;
         if(nivel_do_surfe == 1) {
            //Zero a zero
            Print("Bota no 0/0                  Bota no 0/0");
            preco_stop = preco_entrada;
            trade.PositionModify(ticket_atual, preco_stop, preco_take);
            Print("avanca stop: ", preco_stop, " nivel do surfe:", nivel_do_surfe);
         } else {
            preco_stop = preco_rompido - ((nivel_do_surfe - 1) - desconto_do_stop_no_surfe) * canalMediano;
            trade.PositionModify(ticket_atual, preco_stop, preco_take);
            Print("avanca stop: ", preco_stop, " nivel do surfe:", nivel_do_surfe);
         }
         preco_espera = preco_rompido - (nivel_do_surfe + 1) * canalMediano;
         desenhaEspera();
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double nivel_gerado(int i) {
//Considera preco referencia como topo 0
   return alturaReferencia + i * canalMediano;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int index_nivel_gerado(double preco) {
//Considera altura referencia como topo 0
   int temp = (preco - alturaReferencia) / canalMediano;
   if(preco - nivel_gerado(temp) > 0) temp++;
   return temp;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DesenhaNiveis() {
   ApagarNiveis();
   for(int i = -5; i < 5; i++) {
      string nome = "Linha nível gerado" + i;
      ObjectCreate(0, nome, OBJ_HLINE, 0, 0, nivel_gerado(i + index_nivel_gerado(iClose(_Symbol, PERIOD_CURRENT, 1))));
      ObjectSetInteger(0, nome, OBJPROP_COLOR, C'0x35,0x2B,0xFF');
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ApagarNiveis() {
   ObjectsDeleteAll(0, "Linha nível");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void desenhaEspera() {
   apagaEspera();
   string nome = "Linha espera " + preco_espera;
   ObjectCreate(0, nome, OBJ_HLINE, 0, 0, preco_espera);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, C'0x15,0xFF,0xDC');
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void apagaEspera() {
   ObjectsDeleteAll(0, "Linha espera");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool verificaPosicoes() {
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong bilhete = PositionGetTicket(i);
      if(bilhete != 0) {
         string simbolo = PositionGetString(POSITION_SYMBOL);
         long magica = PositionGetInteger(POSITION_MAGIC);
         if(magica == numeroMagico && simbolo == _Symbol) {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void desenharLinhas() {
   apagarLinhas();
   for(int i = 0; i < ArraySize(posicoes) - 1; i++) {
      string nome = "linha " + i;
      ObjectCreate(0, nome, OBJ_TREND, 0,
                   iTime(_Symbol, PERIOD_CURRENT, posicoes[i]), valores[i],
                   iTime(_Symbol, PERIOD_CURRENT, posicoes[i + 1]), valores[i + 1]);
      ObjectSetInteger(0, nome, OBJPROP_COLOR, clrAqua);
      ObjectSetInteger(0, nome, OBJPROP_WIDTH, 4);
      ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void apagarLinhas() {
   ObjectsDeleteAll(0, "linha");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double distancia_absoluta_tracado(int pos, double valor) {
   return MathAbs(valor - valorTracado(pos));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double valorTracado(int pos) {
   int base = -1;
   for(int i = 1; i < ArraySize(posicoes); i++) {
      if(posicoes[i] >= pos) {
         base = i;
         break;
      }
   }
   double porcentagemBase = (( pos * 1.0 - posicoes[base - 1]) / (posicoes[base] - posicoes[base - 1]));
   double valor = porcentagemBase * (valores[base] - valores[base - 1]) + valores[base - 1];

   return valor;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void insereOrdenado(int posicao, double valor) {
   for (int i = 0; i < ArraySize(posicoes); i++) {
      if(posicoes[i] == posicao) {
         break;
      }
      if(posicoes[i] > posicao) {
         int p[1];
         p[0] = posicao;
         ArrayInsert(posicoes, p, i);

         double v[1];
         v[0] = valor;
         ArrayInsert(valores, v, i);
         break;
      }
   }
}
