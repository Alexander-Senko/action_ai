# frozen_string_literal: true

require "abstract_unit"
require "ruby_llm/tester"
require "action_ai/model_schema"
require "active_model"
require "active_record"
require "sqlite3"

ActiveModel::API.include ActionAI::ModelSchema

class SchemaTest < ActiveSupport::TestCase
  # A simple ActiveModel model used for schema tests
  class PersonModel
    include ::ActiveModel::Model
    include ::ActiveModel::Attributes

    attribute :name,     :string
    attribute :active,   :boolean, default: true
    attribute :role,     :string
    attribute :email,    :string
    attribute :age,      :integer
    attribute :score,    :float
    attribute :height,   :decimal
    attribute :birthday, :date
    attribute :seen_at,  :datetime
    attribute :start_at, :time
    attribute :seed,     :big_integer
    attribute :cert,     :binary

    validates :name,   presence: true, length: { minimum: 2, maximum: 100 }
    validates :active, acceptance: true, allow_nil: false
    validates :role,   inclusion: { in: %w[admin user] }
    validates :email,  format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :age,    numericality: { greater_than: 0, less_than: 130 }
    validates :score,  numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10, multiple_of: 0.1 }
    validates :height, numericality: { greater_than: 0.2, less_than: 2.8, multiple_of: 0.01 }
  end

  class PersonRecord < ActiveRecord::Base
    self.table_name = "people"

    validates :name,   length: { minimum: 2 }
    validates :active, acceptance: true
    validates :role,   inclusion: { in: %w[admin user] }
    validates :email,  format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :age,    numericality: { greater_than: 0, less_than: 130 }
    validates :score,  numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10, multiple_of: 0.1 }
    validates :height, numericality: { greater_than: 0.2, less_than: 2.8 }
  end

  class Response
    include ::ActiveModel::Model
    include ::ActiveModel::Attributes

    attribute :code,        :immutable_string
    attribute :message,     :immutable_string
    attribute :status,      :immutable_string
    attribute :unsupported, ::ActiveModel::Type::Value.new

    validates :code,    length: { is: 3 }
    validates :message, format: { without: /error|failed/ }
    validates :status,  inclusion: { in: ["complete"] }
  end

  class CustomModel
    include ::ActiveModel::Model
    include ::ActiveModel::Attributes

    attribute :name, :string
  end

  class CustomSchema < ActionAI::Schema
    string :name, min_length: 10
  end

  # An agent that uses +returns+ to get structured output
  class PersonAgent < ActionAI::Agent
    def extract_model(json_text)
      returns PersonModel
      ask json_text
    end

    def extract_record(json_text)
      returns PersonRecord
      ask json_text
    end

    def extract_model_array(json_text)
      returns [PersonModel]
      ask json_text
    end

    def extract_record_array(json_text)
      returns [PersonRecord]
      ask json_text
    end
  end

  def self.run_suite(...)
    ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

    ActiveRecord::Schema.define do
      create_table :people do |table|
        table.string   :name,   null: false, limit: 100
        table.boolean  :active, null: false, default: true
        table.string   :role
        table.string   :email
        table.integer  :age
        table.float    :score
        table.decimal  :height, precision: 3, scale: 2
        table.date     :birthday
        table.datetime :seen_at
        table.time     :start_at
        table.binary   :cert
      end
    end

    super

    ActiveRecord::Base.remove_connection
  end

  setup do
    RubyLLM::Tester.interactions.clear
  end

  teardown do
    RubyLLM::Tester.interactions.clear
  end

  # --- ActionAI::ModelSchema ---

  test "ActiveModel model responds to .schema" do
    assert_respond_to PersonModel, :schema
  end

  test "ActiveRecord model responds to .schema" do
    assert_respond_to PersonRecord, :schema
  end

  test ".schema returns a Schematist::Schema instance" do
    assert_kind_of Schematist::Schema, PersonModel.schema
  end

  test ".schema is cached" do
    assert_same PersonModel.schema, PersonModel.schema
  end

  test "custom schema is looked up before inference" do
    assert_instance_of CustomSchema, CustomModel.schema
    assert_equal 10, schema_property(CustomModel, :name)[:minLength]
  end

  test "ActiveModel .schema includes string attributes" do
    assert_equal "string", schema_property(PersonModel, :name)[:type]
  end

  test "ActiveRecord .schema includes string attributes" do
    assert_equal "string", schema_property(PersonRecord, :name)[:type]
  end

  test "ActiveModel .schema includes integer attributes" do
    assert_equal "integer", schema_property(PersonModel, :age )[:type]
    assert_equal "integer", schema_property(PersonModel, :seed)[:type]
  end

  test "ActiveRecord .schema includes integer attributes" do
    assert_equal "integer", schema_property(PersonRecord, :age)[:type]
  end

  test "ActiveModel .schema includes float/decimal attributes as number" do
    assert_equal "number", schema_property(PersonModel, :score )[:type]
    assert_equal "number", schema_property(PersonModel, :height)[:type]
  end

  test "ActiveRecord .schema includes float/decimal attributes as number" do
    assert_equal "number", schema_property(PersonRecord, :score )[:type]
    assert_equal "number", schema_property(PersonRecord, :height)[:type]
  end

  test "ActiveModel .schema includes boolean attributes" do
    assert_equal "boolean", schema_property(PersonModel, :active)[:type]
  end

  test "ActiveRecord .schema includes boolean attributes" do
    assert_equal "boolean", schema_property(PersonRecord, :active)[:type]
  end

  test "ActiveModel .schema includes temporal attributes" do
    assert_equal ["string", "date"],      schema_property(PersonModel, :birthday).values_at(:type, :format)
    assert_equal ["string", "date-time"], schema_property(PersonModel,  :seen_at).values_at(:type, :format)
    assert_equal ["string", "time"],      schema_property(PersonModel, :start_at).values_at(:type, :format)
  end

  test "ActiveRecord .schema includes temporal attributes" do
    assert_equal ["string", "date"],      schema_property(PersonRecord, :birthday).values_at(:type, :format)
    assert_equal ["string", "date-time"], schema_property(PersonRecord,  :seen_at).values_at(:type, :format)
    assert_equal ["string", "time"],      schema_property(PersonRecord, :start_at).values_at(:type, :format)
  end

  test "ActiveModel .schema includes binary attributes" do
    assert_equal ["string", "base64"], schema_property(PersonModel, :cert).values_at(:type, :contentEncoding)
  end

  test "ActiveRecord .schema includes binary attributes" do
    assert_equal ["string", "base64"], schema_property(PersonRecord, :cert).values_at(:type, :contentEncoding)
  end

  test ".schema omits attributes with unsupported types" do
    assert_not_includes schema_properties(Response), "unsupported"
  end

  test "ActiveModel .schema uses the model class name" do
    assert_equal "SchemaTest::PersonModelSchema", PersonModel.to_json_schema[:title]
  end

  test "ActiveRecord .schema uses the model class name" do
    assert_equal "SchemaTest::PersonRecordSchema", PersonRecord.to_json_schema[:title]
  end

  test "ActiveModel .schema marks required attributes" do
    assert_includes PersonModel.to_json_schema[:required], "name"
  end

  test "ActiveRecord .schema marks required attributes" do
    assert_includes PersonRecord.to_json_schema[:required], "name"
    assert_includes PersonRecord.to_json_schema[:required], "active"
  end

  test "ActiveModel .schema includes inferred defaults" do
    assert_equal true, schema_property(PersonModel, :active)[:default]
  end

  test "ActiveRecord .schema includes inferred defaults" do
    assert_equal true, schema_property(PersonRecord, :active)[:default]
  end

  test "ActiveModel .schema includes inferred enums" do
    assert_equal %w[admin user], schema_property(PersonModel, :role)[:enum]

    assert_not_includes schema_property(Response, :status), :enum
  end

  test "ActiveRecord .schema includes inferred enums" do
    assert_equal %w[admin user], schema_property(PersonRecord, :role)[:enum]
  end

  test "ActiveModel .schema includes inferred constants" do
    assert_equal true,       schema_property(PersonModel, :active)[:const]
    assert_equal "complete", schema_property(Response,    :status)[:const]
  end

  test "ActiveRecord .schema includes inferred constants" do
    assert_equal true, schema_property(PersonRecord, :active)[:const]
  end

  test "ActiveModel .schema includes inferred string constraints" do
    assert_equal 2,   schema_property(PersonModel, :name)[:minLength]
    assert_equal 100, schema_property(PersonModel, :name)[:maxLength]
    assert_equal 3,   schema_property(Response,    :code)[:minLength]
    assert_equal 3,   schema_property(Response,    :code)[:maxLength]

    assert_match schema_property(PersonModel, :email)[:pattern], "user@host"
    assert_match schema_property(Response,  :message)[:pattern], ""
    assert_not   schema_property(Response,  :message)[:pattern].match? "Request failed"
  end

  test "ActiveRecord .schema includes inferred string constraints" do
    assert_equal 2,   schema_property(PersonRecord, :name)[:minLength]
    assert_equal 100, schema_property(PersonRecord, :name)[:maxLength]

    assert_equal URI::MailTo::EMAIL_REGEXP, schema_property(PersonRecord, :email)[:pattern]
  end

  test "ActiveModel .schema includes inferred numeric constraints" do
    assert_equal 0,    schema_property(PersonModel, :age   )[:exclusiveMinimum]
    assert_equal 130,  schema_property(PersonModel, :age   )[:exclusiveMaximum]
    assert_equal 0,    schema_property(PersonModel, :score )[:minimum]
    assert_equal 10,   schema_property(PersonModel, :score )[:maximum]
    assert_equal 0.1,  schema_property(PersonModel, :score )[:multipleOf]
    assert_equal 0.2,  schema_property(PersonModel, :height)[:exclusiveMinimum]
    assert_equal 2.8,  schema_property(PersonModel, :height)[:exclusiveMaximum]
    assert_equal 0.01, schema_property(PersonModel, :height)[:multipleOf]
  end

  test "ActiveRecord .schema includes inferred numeric constraints" do
    assert_equal 0,    schema_property(PersonRecord, :age  )[:exclusiveMinimum]
    assert_equal 130,  schema_property(PersonRecord, :age  )[:exclusiveMaximum]
    assert_equal 0,    schema_property(PersonRecord, :score)[:minimum]
    assert_equal 10,   schema_property(PersonRecord, :score)[:maximum]
    assert_equal 0.1,  schema_property(PersonRecord, :score)[:multipleOf]
    assert_equal 0.2,  schema_property(PersonRecord, :height)[:exclusiveMinimum]
    assert_equal 2.8,  schema_property(PersonRecord, :height)[:exclusiveMaximum]
    assert_equal 0.01, schema_property(PersonRecord, :height)[:multipleOf]
  end

  test "ActiveModel .schema marks attributes as not required by default" do
    required = PersonModel.to_json_schema[:required]

    assert_not_includes required, "age"
    assert_not_includes required, "score"
    assert_not_includes required, "role"
    assert_not_includes required, "email"
    assert_not_includes required, "height"
  end

  test "ActiveRecord .schema marks attributes as not required by default" do
    required = PersonRecord.to_json_schema[:required]

    assert_not_includes required, "age"
    assert_not_includes required, "score"
    assert_not_includes required, "role"
    assert_not_includes required, "email"
    assert_not_includes required, "height"
  end

  # --- #returns ---

  test "#returns sets a schema on the chat" do
    model  = PersonAgent.extract_model  '{"name":"Alice","age":30,"score":9.5,"active":true}'
    record = PersonAgent.extract_record '{"name":"Alice","age":30,"score":9.5,"active":true}'
    assert_respond_to model,  :object
    assert_respond_to record, :object
  end

  test "#object returns an instance of the model class" do
    model  = PersonAgent.extract_model  '{"name":"Alice","age":30,"score":9.5,"active":true}'
    record = PersonAgent.extract_record '{"name":"Alice","age":30,"score":9.5,"active":true}'
    assert_instance_of PersonModel,  model .object
    assert_instance_of PersonRecord, record.object
  end

  test "#object has the correct attributes" do
    model  = PersonAgent.extract_model  '{"name":"Alice","age":30,"score":9.5,"active":true}'
    record = PersonAgent.extract_record '{"name":"Alice","age":30,"score":9.5,"active":true}'
    assert_equal "Alice", model .object.name
    assert_equal "Alice", record.object.name
    assert_equal 30,      model .object.age
    assert_equal 30,      record.object.age
  end

  test "#returns accepts an array to declare an array return type" do
    model  = PersonAgent.extract_model_array  '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
    record = PersonAgent.extract_record_array '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
    assert_respond_to model,  :object
    assert_respond_to record, :object
  end

  test "#object returns an array of model instances for array return type" do
    model  = PersonAgent.extract_model_array  '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
    record = PersonAgent.extract_record_array '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
    assert_instance_of Array, model .object
    assert_instance_of Array, record.object
    assert_instance_of PersonModel,  model .object.first
    assert_instance_of PersonRecord, record.object.first
  end

  test "#object array has the correct attributes" do
    model  = PersonAgent.extract_model_array  '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
    record = PersonAgent.extract_record_array '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
    assert_equal 2,       model .object.size
    assert_equal 2,       record.object.size
    assert_equal "Alice", model .object.first.name
    assert_equal "Alice", record.object.first.name
    assert_equal "Bob",   model .object.last.name
    assert_equal "Bob",   record.object.last.name
  end

  private

  def schema_properties(model) = model.to_json_schema[:properties]
  def schema_property(model, name) = schema_properties(model)[name]
end
