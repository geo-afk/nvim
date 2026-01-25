return {
  settings = {
    harper_ls = {
      userDictPath = '../../../../spell/en.utf-8.add',
      workspaceDictPath = '',
      fileDictPath = '',
      linters = {
        SpellCheck = true,
        SpelledNumbers = false,
        AnA = true,
        SentenceCapitalization = true,
        UnclosedQuotes = true,
        WrongQuotes = false,
        LongSentences = true,
        RepeatedWords = true,
        Spaces = true,
        Matcher = true,
        CorrectNumberSuffix = true,
      },
      codeActions = {
        ForceStable = false,
      },
      diagnosticSeverity = 'hint',
      isolateEnglish = false,
      dialect = 'American',
      maxFileLength = 120000,
      ignoredLintsPath = '',
      excludePatterns = {},
    },
  },
}
