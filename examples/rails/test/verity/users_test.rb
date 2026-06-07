# frozen_string_literal: true

# Example Verity tests for a Rails app (place under test/verity/).
#
# Load via examples/rails/test/verity_helper.rb or your own copy.

group "Users API", tags: [:integration] do
  test "creates a user", tags: [:api], tables: [:users] do
    session = integration_session
    session.post "/users", params: { user: { email: "new@example.com" } }
    assert_equal actual: session.response.status, expected: 201
  end
end

test "fixture helper", tags: [:unit] do
  alice = users(:alice)
  assert_equal actual: alice.email, expected: "alice@example.com"
end

test "travel_to helper" do
  travel_to Time.zone.local(2024, 6, 1, 12, 0, 0) do
    assert_equal actual: Time.zone.today.year, expected: 2024
  end
end
