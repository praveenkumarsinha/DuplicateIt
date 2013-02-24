module DuplicateIt

  class RecordSaveError < StandardError
    attr_reader :record

    def initialize(record)
      Rails.logger.debug "Error saving #{record}"
      Rails.logger.debug "Error trace: #{record.errors.inspect}"
      @record = record
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    #Setter method for ignorable_attributes
    def ignore_attributes_while_duplicating(*args)
      @@ignorable_attributes = []
      args.each do |argument|
        if self.attribute_names.include?(argument.to_s)
          @@ignorable_attributes << argument.to_s
        else
          Rails.logger.debug "DuplicateIt: Invalid attribute '#{argument}' in use."
        end
      end
      @@ignorable_attributes = @@ignorable_attributes.uniq
    end

    #Getter method for ignorable_attributes
    def ignorable_attributes
      @@ignorable_attributes ||= ["id", "type", "created_at", "updated_at"]
      @@ignorable_attributes
    end

    #Setter method for ignorable_associations
    def ignore_associations_while_duplicating(*args)
      @@ignorable_associations = []
      args.each do |argument|

        if self.reflect_on_all_associations(:has_many).collect { |has_many_reflection| has_many_reflection.name }.include?(argument.to_sym)
          @@ignorable_associations << argument.to_s
        else
          Rails.logger.debug "DuplicateIt: Invalid association '#{argument}' in use."
        end
      end
      @@ignorable_associations = @@ignorable_associations.uniq
    end

    #Getter method for ignorable_associations
    def ignorable_associations
      @@ignorable_associations ||= []
      @@ignorable_associations.collect { |x| x.to_sym }
    end
  end

  def duplicate
    create_duplicate_of_self(self)
  end

  private

  #Creates a duplicate record from an existing record, ignoring 'ignorable_attributes'
  def create_duplicate_record(record)
    #ignorable_attributes = ["id", "type", "created_at", "updated_at"]
    record_attributes = record.attributes
    self.class.ignorable_attributes.each { |ignorable_attribute| record_attributes.delete(ignorable_attribute) }

    duplicate_record = record.class.new(record_attributes)
    if duplicate_record.save
      return duplicate_record
    else
      raise RecordSaveError.new(duplicate_record)
    end
    return nil
  end

  #Creates a duplicate of self
  def create_duplicate_of_self(record)
#    Approach-I: Using FILO technique to create object starting form last node children
#    if record.class.reflect_on_all_associations(:has_many).size > 0
#      record.class.reflect_on_all_associations(:has_many).each do |has_many_reflection|
#        children_records = record.send(has_many_reflection.name).collect { |has_many_record| create_duplicate_of_self(has_many_record) }
#        duplicate_record = create_duplicate_record(record)
#        puts "===================== #{duplicate_record.errors.inspect}"
#        duplicate_record.send("#{has_many_reflection.name}=", children_records) unless duplicate_record.nil?
#        return duplicate_record
#      end
#    else
#      return create_duplicate_record(record)
#    end


#    Approach-II : Using FIFO technique to create object starting from trunk and then traversing to children node
    duplicate_record = create_duplicate_record(record)
    unless duplicate_record.nil?
      record.class.reflect_on_all_associations(:has_many).each do |has_many_reflection|
        if self.class.ignorable_associations.include?(has_many_reflection.name)
          Rails.logger.info "DuplicateIt: Ignoring association '#{has_many_reflection}' for #{record.inspect}."
        else
          if record.send(has_many_reflection.name).count > 0
            record.send(has_many_reflection.name).each do |has_many_record|
              duplicate_record.send("#{has_many_reflection.name}=", (duplicate_record.send("#{has_many_reflection.name}") + [create_duplicate_of_self(has_many_record)]))
            end
          end
        end
      end
    end

    return duplicate_record
  end
end

#Adding to ActiveRecord::Base 
class ActiveRecord::Base
  include DuplicateIt
end

