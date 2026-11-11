namespace AtInheritanceLimit;

// 5 classes, each deriving from the one before: CA1501 reports a depth of inheritance of 5.
public class Level01;
public class Level02 : Level01;
public class Level03 : Level02;
public class Level04 : Level03;
public class Level05 : Level04;
