import unit_threaded.runner : runTestsMain;

mixin runTestsMain!(
    "pc4d",
    "pc4d.parser",
    "pc4d.parsers",
);
