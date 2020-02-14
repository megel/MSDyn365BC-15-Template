codeunit 50148 "CCO Test Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    begin
        SetupTestSuite();
    end;

    procedure SetupTestSuite()
    var
        ALTestSuite: Record "AL Test Suite";
        TestSuiteMgt: Codeunit "Test Suite Mgt.";
        SuiteName: Code[10];
    begin
        SuiteName := 'DEFAULT';
        if ALTestSuite.Get(SuiteName) then
            ALTestSuite.DELETE(true);

        TestSuiteMgt.CreateTestSuite(SuiteName);
        Commit();
        ALTestSuite.Get(SuiteName);
        TestSuiteMgt.SelectTestMethodsByRange(ALTestSuite, '50000..99999');
    end;
}
