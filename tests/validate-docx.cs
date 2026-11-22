#:package DocumentFormat.OpenXml@3.5.1
#:property PublishAot=false
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Validation;

if (args.Length == 0)
{
    Console.Error.WriteLine("Pass the reference or freshly rendered DOCX files to validate.");
    return 2;
}

var validator = new OpenXmlValidator(FileFormatVersions.Microsoft365) { MaxNumberOfErrors = 0 };
var total = 0;
foreach (var path in args)
{
    using var document = WordprocessingDocument.Open(path, false);
    var count = 0;
    foreach (var error in validator.Validate(document))
    {
        Console.Error.WriteLine($"{path} {error.Part?.Uri} {error.Path?.XPath} {error.Description}");
        count++;
    }
    Console.WriteLine($"{path}: {count} error(s)");
    total += count;
}
return total == 0 ? 0 : 1;
