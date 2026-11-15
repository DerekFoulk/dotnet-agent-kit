namespace AtInheritanceLimit;

// 6 classes, each deriving from the one before: CA1501 reports the last as 5 levels deep (base classes in this module).
/// <summary>A public member of this fixture (STY-008).</summary>
public class Level01;
/// <summary>A public member of this fixture (STY-008).</summary>
public class Level02 : Level01;
/// <summary>A public member of this fixture (STY-008).</summary>
public class Level03 : Level02;
/// <summary>A public member of this fixture (STY-008).</summary>
public class Level04 : Level03;
/// <summary>A public member of this fixture (STY-008).</summary>
public class Level05 : Level04;
/// <summary>A public member of this fixture (STY-008).</summary>
public class Level06 : Level05;
