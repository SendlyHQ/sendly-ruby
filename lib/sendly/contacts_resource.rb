# frozen_string_literal: true

module Sendly
  class Contact
    attr_reader :id, :phone_number, :name, :email, :metadata, :opted_out,
                :created_at, :updated_at, :lists

    def initialize(data)
      @id = data["id"]
      @phone_number = data["phone_number"] || data["phoneNumber"]
      @name = data["name"]
      @email = data["email"]
      @metadata = data["metadata"] || {}
      @opted_out = data["opted_out"] || data["optedOut"] || false
      @created_at = parse_time(data["created_at"] || data["createdAt"])
      @updated_at = parse_time(data["updated_at"] || data["updatedAt"])
      @lists = data["lists"]&.map { |l| { id: l["id"], name: l["name"] } }
    end

    def opted_out?
      opted_out
    end

    def to_h
      {
        id: id, phone_number: phone_number, name: name, email: email,
        metadata: metadata, opted_out: opted_out,
        created_at: created_at&.iso8601, updated_at: updated_at&.iso8601,
        lists: lists
      }.compact
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  class ContactList
    attr_reader :id, :name, :description, :contact_count, :created_at,
                :updated_at, :contacts, :contacts_total

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @description = data["description"]
      @contact_count = data["contact_count"] || data["contactCount"] || 0
      @created_at = parse_time(data["created_at"] || data["createdAt"])
      @updated_at = parse_time(data["updated_at"] || data["updatedAt"])
      @contacts = data["contacts"]&.map do |c|
        {
          id: c["id"],
          phone_number: c["phone_number"] || c["phoneNumber"],
          name: c["name"],
          email: c["email"]
        }
      end
      @contacts_total = data["contacts_total"] || data["contactsTotal"]
    end

    def to_h
      {
        id: id, name: name, description: description,
        contact_count: contact_count, created_at: created_at&.iso8601,
        updated_at: updated_at&.iso8601, contacts: contacts,
        contacts_total: contacts_total
      }.compact
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  class ContactListsResource
    def initialize(client)
      @client = client
    end

    def list
      response = @client.get("/contact-lists")
      lists = (response["lists"] || []).map { |l| ContactList.new(l) }
      { lists: lists }
    end

    def get(id, limit: nil, offset: nil)
      params = {}
      params[:limit] = limit if limit
      params[:offset] = offset if offset

      response = @client.get("/contact-lists/#{id}", params)
      ContactList.new(response)
    end

    def create(name:, description: nil)
      body = { name: name }
      body[:description] = description if description

      response = @client.post("/contact-lists", body)
      ContactList.new(response)
    end

    def update(id, name: nil, description: nil)
      body = {}
      body[:name] = name if name
      body[:description] = description unless description.nil?

      response = @client.patch("/contact-lists/#{id}", body)
      ContactList.new(response)
    end

    def delete(id)
      @client.delete("/contact-lists/#{id}")
    end

    def add_contacts(list_id, contact_ids)
      response = @client.post("/contact-lists/#{list_id}/contacts", { contact_ids: contact_ids })
      { added_count: response["added_count"] || response["addedCount"] }
    end

    def remove_contact(list_id, contact_id)
      @client.delete("/contact-lists/#{list_id}/contacts/#{contact_id}")
    end
  end

  class ContactsResource
    attr_reader :lists

    def initialize(client)
      @client = client
      @lists = ContactListsResource.new(client)
    end

    def list(limit: nil, offset: nil, search: nil, list_id: nil)
      params = {}
      params[:limit] = limit if limit
      params[:offset] = offset if offset
      params[:search] = search if search
      params[:list_id] = list_id if list_id

      response = @client.get("/contacts", params)
      contacts = (response["contacts"] || []).map { |c| Contact.new(c) }
      {
        contacts: contacts,
        total: response["total"],
        limit: response["limit"],
        offset: response["offset"]
      }
    end

    def get(id)
      response = @client.get("/contacts/#{id}")
      Contact.new(response)
    end

    def create(phone_number:, name: nil, email: nil, metadata: nil)
      body = { phone_number: phone_number }
      body[:name] = name if name
      body[:email] = email if email
      body[:metadata] = metadata if metadata

      response = @client.post("/contacts", body)
      Contact.new(response)
    end

    def update(id, name: nil, email: nil, metadata: nil)
      body = {}
      body[:name] = name unless name.nil?
      body[:email] = email unless email.nil?
      body[:metadata] = metadata unless metadata.nil?

      response = @client.patch("/contacts/#{id}", body)
      Contact.new(response)
    end

    def delete(id)
      @client.delete("/contacts/#{id}")
    end

    def import_contacts(contacts, list_id: nil, opted_in_at: nil)
      body = {
        contacts: contacts.map { |c|
          h = { phone: c[:phone] }
          h[:name] = c[:name] if c[:name]
          h[:email] = c[:email] if c[:email]
          h[:optedInAt] = c[:opted_in_at] if c[:opted_in_at]
          h
        }
      }
      body[:listId] = list_id if list_id
      body[:optedInAt] = opted_in_at if opted_in_at

      response = @client.post("/contacts/import", body)
      {
        imported: response["imported"],
        skipped_duplicates: response["skippedDuplicates"],
        errors: response["errors"] || [],
        total_errors: response["totalErrors"] || 0
      }
    end
  end
end
