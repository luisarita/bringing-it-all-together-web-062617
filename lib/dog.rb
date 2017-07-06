class Dog
    attr_accessor :id, :name, :breed

    PRIMARY_KEY = "id"
    ATTRIBUTES = {
        "id" => "integer",
        "name" => "text",
        "breed" => "text"
    }

    def self.find_by_id(argument)
        find_by_fields({:id => argument})
    end

    def self.find_by_name(argument)
        find_by_fields({:name => argument})
    end

    def self.find_or_create_by(hash)
        instance = find_by_fields(hash)
        if instance.nil?
            instance = create(hash)
        end
        instance
    end

    def self.find_by_fields(hash)
        values = []
        search_fields = hash.map do |key, value|
            values << value
            "#{key}=?"
        end.join(" AND ")
        sql_statement = <<-SQL
            SELECT #{ATTRIBUTES.keys.join(",")} FROM #{table_name} WHERE #{search_fields}
        SQL
        rows = DB[:conn].execute(sql_statement, values)
        new_from_db(rows[0])
    end

    def initialize(attributes)
        attributes.each do |attribute, value|
            self.send("#{attribute}=", value)
        end
    end

    def self.primary_key_type
        ATTRIBUTES.select {|attribute| attribute == PRIMARY_KEY }.map {|attribute, datatype| datatype}[0]
    end
    
    def self.table_name
        "#{self.to_s.downcase}s"
    end

    def self.fields_with_type
        ATTRIBUTES.select {|attribute| attribute != PRIMARY_KEY}.map do |attribute, datatype|
            "#{attribute} #{datatype.upcase}" 
        end
    end

    def self.fields
        ATTRIBUTES.select {|attribute| attribute != PRIMARY_KEY}.map do |attribute, datatype|
            "#{attribute}" 
        end
    end

    def values
        self.class.fields.collect do |field|
            self.send(field)
        end
    end

    def self.create(attributes)
        new_object = self.new(attributes)
        new_object.save
    end

    def self.create_table
        sql_statement = <<-SQL
            CREATE TABLE IF NOT EXISTS #{table_name} (#{PRIMARY_KEY} #{primary_key_type.upcase} PRIMARY KEY, #{fields_with_type.join(", ")});
        SQL
        DB[:conn].execute(sql_statement)
    end

    def self.drop_table
        sql_statement = <<-SQL
            DROP TABLE IF EXISTS #{table_name};
        SQL
        DB[:conn].execute(sql_statement)
    end

    def insert
        question_marks = (fields.length.times).map {"?"}.join(",")
        sql_statement = <<-SQL
            INSERT INTO #{table_name} (#{self.class.fields.join(", ")}) VALUES (#{question_marks});
        SQL
        DB[:conn].execute(sql_statement, *values)
        sql_statement = "SELECT last_insert_rowid()"
        @id = DB[:conn].execute(sql_statement)[0][0]
    end

    def update
        fields_with_question_marks = fields.map {|field| "#{field}=?" }.join(",")
        sql_statement = <<-SQL
            UPDATE #{table_name} SET #{fields_with_question_marks} WHERE #{PRIMARY_KEY}=?
        SQL
        DB[:conn].execute(sql_statement, *values, id)
    end

    def self.new_from_db(row)
        return nil if row.nil?
        hash = {}
        ATTRIBUTES.keys.each_with_index do |attribute, index|
            hash[attribute] = row[index]
        end
        #binding.pry
        self.new(hash)
    end

    def persisted?
        !!@id
    end
    def save
        if persisted?
            update
        else
            insert
        end
        self
    end

    #helper functions
    def table_name
        self.class.table_name
    end

    def primary_key_type
        self.class.primary_key_type
    end

    def fields
        self.class.fields
    end

end