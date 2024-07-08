object DataModuleMain: TDataModuleMain
  Height = 480
  Width = 640
  object FDPhysMSSQLDriverLink: TFDPhysMSSQLDriverLink
    Left = 304
    Top = 224
  end
  object FDConnection: TFDConnection
    Left = 352
    Top = 344
  end
  object FDQueryMain: TFDQuery
    Connection = FDConnection
    Left = 224
    Top = 352
  end
  object FDQueryCheck: TFDQuery
    Connection = FDConnection
    Left = 104
    Top = 352
  end
end
