public class CommentFormatter {
    public class CommentWrapper {
        public String creatorName;
        public String content;
        public DateTime commentTime;

        public CommentWrapper(String creatorName, String content, DateTime commentTime) {
            this.creatorName = creatorName;
            this.content = content;
            this.commentTime = commentTime;
        }
    }

    public static String formatComments(List<CommentWrapper> comments, List<String> labels) {
        // Sort comments by commentTime in descending order (Newest First)
        comments.sort(new DescendingComparator());

        String formattedComments = '';

        // Create label bubbles with dynamic colors
        String labelBubbles = '<div style="margin-bottom: 10px;">';

        for (String label : labels) {
            String color = getLabelColor(label.capitalize()); // Get the color for the label

            // Fixed Salesforce rendering issue for rounded bubbles
            labelBubbles += '<span style="background-color:' + color + '; color:white; padding:4px 8px; ' +
                    'border-radius: 50px; margin-right:5px; display:inline-flex; align-items:center; ' +
                    'border: 1px solid transparent; line-height: 1.5; font-size: 80%; white-space: nowrap;">' +
                    label.capitalize() + '</span> ';
        }

        labelBubbles += '</div>'; // Close label container
        formattedComments += labelBubbles; // Add label bubbles to the top

        // Format each comment (right-aligned)
        formattedComments += '<div style="text-align: right;">'; // Align all comments to the right

        for (CommentWrapper comment : comments) {
            String formattedCommentTime = comment.commentTime.format('yyyy-MM-dd HH:mm:ss');

            String richText = '<b>Comment by:</b> <span style="color:blue;">{CreatorName}</span><br>' +
                    '<i>Time:</i> {CommentTime}<br>' +
                    '<p>{Content}</p><br>'; // Adds spacing between comments

            richText = richText.replace('{CreatorName}', comment.creatorName)
                    .replace('{Content}', comment.content)
                    .replace('{CommentTime}', formattedCommentTime);

            formattedComments += richText + '<br>'; // Extra space between comments
        }

        formattedComments += '</div>'; // Close right-align div

        return formattedComments;
    }

    // Determines the label color based on the category
    private static String getLabelColor(String label) {
        Set<String> purpleLabels = new Set<String>{'Finance', 'Timeline issue', 'Finance (personal)'};
        Set<String> orangeLabels = new Set<String>{'Appointment', 'Follow up', 'Get back in', 'Need update', 'Pick up check'};
        Set<String> redLabels = new Set<String>{'Canceled deal', 'Ncy', 'Dnc', 'No good', 'No show',
                'Purchased elsewhere', 'Reset', 'Dnr', 'Finance unapproved',
                'Lost', 'No demo', 'No interest'};
        Set<String> yellowLabels = new Set<String>{'In progress', 'Rehash'};
        Set<String> blueLabels = new Set<String>{'Bid', 'Ordered'};
        Set<String> greenLabels = new Set<String>{'Finance approved', 'Mailing check', 'Paid', 'Sold'};

        if (purpleLabels.contains(label)) return 'purple';
        if (orangeLabels.contains(label)) return 'orange';
        if (redLabels.contains(label)) return 'red';
        if (yellowLabels.contains(label)) return '#FFC107'; // Darker yellow (Amber)
        if (blueLabels.contains(label)) return 'blue';
        if (greenLabels.contains(label)) return 'green';

        return 'lightgrey'; // Default color for labels not in the predefined categories
    }

    // Custom Comparator for sorting by commentTime in descending order
    public class DescendingComparator implements System.Comparator<CommentWrapper> {
        public Integer compare(CommentWrapper a, CommentWrapper b) {
            if (a.commentTime == null && b.commentTime == null) return 0;
            if (a.commentTime == null) return 1;
            if (b.commentTime == null) return -1;

            Long timeA = a.commentTime.getTime();
            Long timeB = b.commentTime.getTime();

            if (timeA > timeB) return -1; // Newest first
            if (timeA < timeB) return 1;  // Oldest last
            return 0; // Same timestamp
        }
    }
}