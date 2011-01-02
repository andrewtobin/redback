class Entry
    attr_accessor :Title, :MetaTitle, :PublishDate,
        :Name, :Summary, :IsVisable, :Revisions, :Comments, :Pingbacks,
        :MetaDescription, :MetaKeywords, :IsDiscussionEnabled, :IsNew,
        :Reason, :Feeds, :Content
        
    def initialize
        @Title = ''
        @Name = ''
        @Summary = ''
        @Content = ''
        @IsVisable = true
        @Revisions = Array.new
        @Comments = Array.new
        @Pingbacks = Array.new
        @Feeds = Array.new
        @IsDiscussionEnabled = true
        @IsNew = true
    end
end