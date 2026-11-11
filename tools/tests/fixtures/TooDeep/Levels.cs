namespace TooDeep;

// 6 classes, each deriving from the one before: CA1501 reports a depth of inheritance of 6.
public class Level01;
public class Level02 : Level01;
public class Level03 : Level02;
public class Level04 : Level03;
public class Level05 : Level04;
public class Level06 : Level05;
