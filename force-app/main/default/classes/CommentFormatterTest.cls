/**
 * Created by Devin on 1/29/2025.
 */
@isTest
public with sharing class CommentFormatterTest {
    @IsTest
    static void testFormatComments() {
        // Create test comments
        List<CommentFormatter.CommentWrapper> testComments = new List<CommentFormatter.CommentWrapper>{
                new CommentFormatter.CommentWrapper('Alice', 'This is the first comment', DateTime.now().addDays(-1)),
                new CommentFormatter.CommentWrapper('Bob', 'Second comment', DateTime.now().addHours(-5)),
                new CommentFormatter.CommentWrapper('Charlie', 'Most recent comment', DateTime.now())
        };

        // Create test labels
        List<String> testLabels = new List<String>{'Finance', 'Follow up', 'Canceled deal', 'In progress', 'Unknown Label'};

        // Call the method
        String result = CommentFormatter.formatComments(testComments, testLabels);

        // ✅ Ensure result contains formatted comments
        System.assert(result.contains('Alice'), 'Alice should be in the result');
        System.assert(result.contains('Bob'), 'Bob should be in the result');
        System.assert(result.contains('Charlie'), 'Charlie should be in the result');

        // ✅ Ensure sorting order (Charlie should be first)
        Integer charlieIndex = result.indexOf('Charlie');
        Integer bobIndex = result.indexOf('Bob');
        Integer aliceIndex = result.indexOf('Alice');
        System.assert(charlieIndex < bobIndex, 'Charlie should appear before Bob');
        System.assert(bobIndex < aliceIndex, 'Bob should appear before Alice');

        // ✅ Ensure labels are properly formatted with new colors
        System.assert(result.contains('background-color:purple'), 'Finance label should be purple');
        System.assert(result.contains('background-color:orange'), 'Follow up label should be orange');
        System.assert(result.contains('background-color:red'), 'Canceled deal label should be red');
        System.assert(result.contains('background-color:#FFC107'), 'In progress label should be dark yellow');
        System.assert(result.contains('background-color:lightgrey'), 'Unknown Label should be light grey');
    }

    @IsTest
    static void testFormatCommentsEmptyLists() {
        // Call method with empty lists
        String result = CommentFormatter.formatComments(new List<CommentFormatter.CommentWrapper>(), new List<String>());

        // ✅ Ensure it does not crash and returns a valid empty structure
        System.assert(result != null, 'Result should not be null');
        System.assert(!result.contains('Comment by'), 'There should be no comments in the result');
    }

    @IsTest
    static void testDescendingComparator() {
        CommentFormatter.CommentWrapper oldComment = new CommentFormatter.CommentWrapper('Old', 'Older comment', DateTime.now().addDays(-2));
        CommentFormatter.CommentWrapper newComment = new CommentFormatter.CommentWrapper('New', 'Newer comment', DateTime.now());

        CommentFormatter.DescendingComparator comparator = new CommentFormatter.DescendingComparator();

        // ✅ Newer comments should come first
        System.assert(comparator.compare(newComment, oldComment) < 0, 'New comment should be first');
        System.assert(comparator.compare(oldComment, newComment) > 0, 'Old comment should be last');
        System.assert(comparator.compare(newComment, newComment) == 0, 'Same comment should be equal');
    }
}