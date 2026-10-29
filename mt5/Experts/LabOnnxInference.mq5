//+------------------------------------------------------------------+
//| LabOnnxInference.mq5                                             |
//| Inference-only ONNX harness. It never places, modifies or closes |
//| orders and never connects to a broker account.                   |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "ONNX inference harness; no trading calls."
// The Strategy Tester agent starts with an empty MQL5\Files sandbox, so the
// model and fixture must be declared here to be copied to the agent.
#property tester_file "model.onnx"
#property tester_file "onnx_feature_fixture.csv"

input string InpModelFile    = "model.onnx";                 // relative to MQL5/Files
input string InpFeatureFile  = "onnx_feature_fixture.csv";   // relative to MQL5/Files
input int    InpFeatureCount = 12;                           // must match model metadata
input int    InpMaxRows      = 0;                            // 0 = all rows

long g_onnx = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpFeatureCount <= 0)
     {
      PrintFormat("invalid feature count: %d", InpFeatureCount);
      return INIT_PARAMETERS_INCORRECT;
     }

   g_onnx = OnnxCreate(InpModelFile, ONNX_DEFAULT);
   if(g_onnx == INVALID_HANDLE)
     {
      PrintFormat("OnnxCreate failed for %s, error %d", InpModelFile, GetLastError());
      return INIT_FAILED;
     }

   long input_shape[] = {1, InpFeatureCount};
   if(!OnnxSetInputShape(g_onnx, 0, input_shape))
     {
      PrintFormat("OnnxSetInputShape failed, error %d", GetLastError());
      OnnxRelease(g_onnx);
      g_onnx = INVALID_HANDLE;
      return INIT_FAILED;
     }

   long output_shape[] = {1, 1};
   if(!OnnxSetOutputShape(g_onnx, 0, output_shape))
     {
      PrintFormat("OnnxSetOutputShape failed, error %d", GetLastError());
      OnnxRelease(g_onnx);
      g_onnx = INVALID_HANDLE;
      return INIT_FAILED;
     }

   RunFixture();
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_onnx != INVALID_HANDLE)
     {
      OnnxRelease(g_onnx);
      g_onnx = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   // Intentionally empty: this harness only evaluates a fixed fixture.
  }

//+------------------------------------------------------------------+
void RunFixture()
  {
   int file = FileOpen(InpFeatureFile, FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(file == INVALID_HANDLE)
     {
      PrintFormat("cannot open %s, error %d", InpFeatureFile, GetLastError());
      return;
     }

   for(int column = 0; column < InpFeatureCount; column++)
      FileReadString(file);

   int row = 0;
   while(!FileIsEnding(file) && (InpMaxRows <= 0 || row < InpMaxRows))
     {
      matrixf features(1, InpFeatureCount);
      bool complete = true;
      for(int column = 0; column < InpFeatureCount; column++)
        {
         string token = FileReadString(file);
         if(StringLen(token) == 0)
           {
            complete = false;
            break;
           }
         double value = StringToDouble(token);
         if(!MathIsValidNumber(value))
           {
            complete = false;
            break;
           }
         features[0][column] = (float)value;
        }
      if(!complete)
         break;

      matrixf prediction(1, 1);
      if(!OnnxRun(g_onnx, ONNX_DEFAULT, features, prediction))
        {
         PrintFormat("OnnxRun failed at row %d, error %d", row, GetLastError());
         break;
        }

      PrintFormat("onnx_row=%d probability=%.8f", row, (double)prediction[0][0]);
      row++;
     }

   FileClose(file);
   PrintFormat("onnx_rows=%d model=%s", row, InpModelFile);
  }
//+------------------------------------------------------------------+
