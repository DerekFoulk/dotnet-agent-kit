namespace TooDeep;

// 7 classes, each deriving from the one before: CA1501 reports the last as 6 levels deep (base classes in this module).
public class Level01;
public class Level02 : Level01;
public class Level03 : Level02;
public class Level04 : Level03;
public class Level05 : Level04;
public class Level06 : Level05;
public class Level07 : Level06;
