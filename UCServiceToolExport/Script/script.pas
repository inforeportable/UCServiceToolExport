const
app_version =  'UCServiceToolExport  App Version :  2026-06-05 04:41';
var
splitter01 : Tsplitter ;
WinHttpReq : Variant;
procedure app_start ;
var
url : String;
RawText : String;
begin                            
    Try
        Form1.Caption := app_version ;
        url := 'https://raw.githubusercontent.com/inforeportable/UCServiceToolExport/refs/heads/main/sql/hosxp_uc_export_money_main.sql';
        WinHttpReq.Open('GET', Url, False);
        WinHttpReq.Send;
        if WinHttpReq.Status = 200 then
        begin
            Form1.Memo1.Clear;
            RawText := WinHttpReq.ResponseText;
            RawText := ReplaceStr(RawText, #10, #13#10);
            Form1.Button1.dbSQL := RawText ;
            Form1.Memo1.Text := RawText;
            Form1.TabSheet3.Visible := False ;
        end
        else
        begin
            ShowMessage('ดึงข้อมูลไม่สำเร็จ (Server Error)! โปรแกรมจะปิดตัวลง');
            Form1.Close ;
        end;
        Except
        ShowMessage('ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้! โปรแกรมจะปิดตัวลง');
        Form1.Close ;
    End;
end;
procedure Form1_OnShow (Sender: TObject; Action: string);
begin
    Form1.mniFile.Visible := False;
    Form1.mniOptions.Visible := True;
    Form1.mniSettings.Visible := False;
    Form1.mniReport.Visible := True;
    Form1.mniAbout.Visible := False;
    Form1.mniImportData.Visible := False;
    Form1.mniExportData.Visible := False;
end;
procedure Form1_Button6_OnAfterClick (Sender: TObject);
begin
    Showmessage('Clear OK!');
end;
procedure Form1_TableGrid1_OnCellDoubleClick (Sender: TObject; ACol, ARow: Integer);
begin
    Form1.TableGrid2.dbSQL :=
    'SELECT * FROM uc_export_money_tranform_list_head_descr where vn = "'+
    Form1.TableGrid1.Cells[7, Form1.TableGrid1.SelectedRow]+'" ;' ;
    Form1.TableGrid2.dbSQLExecute ;
end;
procedure Form1_Button1_OnAfterClick (Sender: TObject);
begin
    Form1.TableGrid1.dbSQL := 'SELECT * FROM uc_export_money_tranform_list_head;';
    Form1.TableGrid1.dbSQLExecute ;
    Form1.TableGrid2.dbSQL := 'SELECT * FROM uc_export_money_tranform_list_head_descr;';
    Form1.TableGrid2.dbSQLExecute ;
end;
procedure Form1_TableGrid2_OnChange (Sender: TObject);
begin
    Form1.TableGrid2.BestFitColumns(bfboth) ;
end;
procedure Form1_TableGrid1_OnChange (Sender: TObject);
begin
    Form1.TableGrid1.BestFitColumns(bfboth) ;
end;
begin
    splitter01 := Tsplitter.Create(Form1) ;
    splitter01.Parent := Form1.Panel2 ;
    Form1.Panel3.Align := Altop ;
    splitter01.Align := Altop ;
    splitter01.Top := 100 ;
    Form1.Panel4.Align := Alclient;
    WinHttpReq := CreateOleObject('WinHttp.WinHttpRequest.5.1');
    app_start ;
end.
